const fs = require('fs');
const path = require('path');

/**
 * 替换QueryData合约中的地址常量
 * @param {string} chainName - 链名称 (如: eth, bsc, polygon等)
 */
async function replaceAddresses(chainName) {
    try {
        // 读取地址配置文件
        const addressFilePath = path.join(__dirname, 'addresses', `${chainName}.json`);
        
        if (!fs.existsSync(addressFilePath)) {
            console.error(`地址文件不存在: ${addressFilePath}`);
            return;
        }

        const addresses = JSON.parse(fs.readFileSync(addressFilePath, 'utf8'));
        console.log(`读取 ${chainName} 链的地址配置:`, addresses);

        // 读取合约文件
        const contractPath = path.join(__dirname, '..', 'src', 'Quote.sol');
        let contractContent = fs.readFileSync(contractPath, 'utf8');

        // 定义需要替换的常量及其默认值（0地址）
        const constants = {
            'POOL_MANAGER': '0x0000000000000000000000000000000000000000',
            'STATE_VIEW': '0x0000000000000000000000000000000000000000',
            'POSITION_MANAGER': '0x0000000000000000000000000000000000000000',
            'FLUID_LITE_DEX': '0x0000000000000000000000000000000000000000',
            'FLUID_LITE_DEPLOYER_CONTRACT': '0x0000000000000000000000000000000000000000'
        };

        // 替换每个常量
        for (const [constantName, defaultAddress] of Object.entries(constants)) {
            // 使用JSON文件中的地址，如果不存在则使用0地址
            const newAddress = addresses[constantName] || defaultAddress;
            
            // 构建正则表达式来匹配常量声明
            const regex = new RegExp(
                `(address\\s+public\\s+constant\\s+${constantName}\\s*=\\s*)0x[a-fA-F0-9]{40}`,
                'g'
            );
            
            // 检查是否找到匹配
            const matches = contractContent.match(regex);
            
            if (matches && matches.length > 0) {
                // 执行替换
                const oldContent = contractContent;
                contractContent = contractContent.replace(regex, `$1${newAddress}`);
                
                if (oldContent !== contractContent) {
                    console.log(`✅ 已替换 ${constantName}: ${newAddress}`);
                } else {
                    console.log(`ℹ️  ${constantName} 地址已经是目标地址: ${newAddress}`);
                }
            } else {
                console.log(`⚠️  未找到 ${constantName} 常量声明`);
            }
        }

        // 写回文件
        fs.writeFileSync(contractPath, contractContent, 'utf8');
        console.log(`\n🎉 成功更新合约文件: ${contractPath}`);
        
    } catch (error) {
        console.error('替换地址时发生错误:', error);
    }
}

/**
 * 创建新链的地址配置文件模板
 * @param {string} chainName - 链名称
 */
function createAddressTemplate(chainName) {
    const addressFilePath = path.join(__dirname, 'addresses', `${chainName}.json`);
    
    if (fs.existsSync(addressFilePath)) {
        console.log(`地址文件已存在: ${addressFilePath}`);
        return;
    }

    const template = {
        "POOL_MANAGER": "0x0000000000000000000000000000000000000000",
        "STATE_VIEW": "0x0000000000000000000000000000000000000000", 
        "POSITION_MANAGER": "0x0000000000000000000000000000000000000000",
        "FLUID_LITE_DEX": "0x0000000000000000000000000000000000000000",
        "FLUID_LITE_DEPLOYER_CONTRACT": "0x0000000000000000000000000000000000000000"
    };

    fs.writeFileSync(addressFilePath, JSON.stringify(template, null, 2), 'utf8');
    console.log(`✅ 已创建地址配置模板: ${addressFilePath}`);
}

/**
 * 显示使用帮助
 */
function showHelp() {
    console.log(`
使用方法:
  node scripts/replace_addresses.js <command> [chainName]

命令:
  replace <chainName>  - 使用指定链的地址配置替换合约中的常量
  create <chainName>   - 为指定链创建地址配置文件模板
  help                 - 显示此帮助信息

示例:
  node scripts/replace_addresses.js replace eth
  node scripts/replace_addresses.js create bsc
  node scripts/replace_addresses.js help
    `);
}

// 主函数
async function main() {
    const args = process.argv.slice(2);
    
    if (args.length === 0) {
        showHelp();
        return;
    }

    const command = args[0];
    const chainName = args[1];

    switch (command) {
        case 'replace':
            if (!chainName) {
                console.error('错误: 请指定链名称');
                showHelp();
                return;
            }
            await replaceAddresses(chainName);
            break;
            
        case 'create':
            if (!chainName) {
                console.error('错误: 请指定链名称');
                showHelp();
                return;
            }
            createAddressTemplate(chainName);
            break;
            
        case 'help':
            showHelp();
            break;
            
        default:
            console.error(`错误: 未知命令 "${command}"`);
            showHelp();
    }
}

// 运行主函数
if (require.main === module) {
    main().catch(console.error);
}

module.exports = {
    replaceAddresses,
    createAddressTemplate
};
