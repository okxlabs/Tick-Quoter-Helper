const fs = require('fs');
const path = require('path');

/**
 * Replace address constants in QueryData contract
 * @param {string} chainName - Chain name (e.g.: eth, bsc, polygon, etc.)
 */
async function replaceAddresses(chainName) {
    try {
        // Read address configuration file
        const addressFilePath = path.join(__dirname, 'addresses', `${chainName}.json`);
        
        if (!fs.existsSync(addressFilePath)) {
            console.error(`Address file does not exist: ${addressFilePath}`);
            return;
        }

        const addresses = JSON.parse(fs.readFileSync(addressFilePath, 'utf8'));
        console.log(`Reading ${chainName} chain address configuration:`, addresses);

        // Read contract file
        const contractPath = path.join(__dirname, '..', 'src', 'Quote.sol');
        let contractContent = fs.readFileSync(contractPath, 'utf8');

        // Define constants to be replaced and their default values (0 address)
        const constants = {
            'POOL_MANAGER': '0x0000000000000000000000000000000000000000',
            'STATE_VIEW': '0x0000000000000000000000000000000000000000',
            'POSITION_MANAGER': '0x0000000000000000000000000000000000000000',
            'FLUID_LITE_DEX': '0x0000000000000000000000000000000000000000',
            'FLUID_LITE_DEPLOYER_CONTRACT': '0x0000000000000000000000000000000000000000'
        };

        // Replace each constant
        for (const [constantName, defaultAddress] of Object.entries(constants)) {
            // Use address from JSON file, if not exists then use 0 address
            const newAddress = addresses[constantName] || defaultAddress;
            
            // Build regex to match constant declaration
            const regex = new RegExp(
                `(address\\s+public\\s+constant\\s+${constantName}\\s*=\\s*)0x[a-fA-F0-9]{40}`,
                'g'
            );
            
            // Check if matches are found
            const matches = contractContent.match(regex);
            
            if (matches && matches.length > 0) {
                // Execute replacement
                const oldContent = contractContent;
                contractContent = contractContent.replace(regex, `$1${newAddress}`);
                
                if (oldContent !== contractContent) {
                    console.log(`✅ Replaced ${constantName}: ${newAddress}`);
                } else {
                    console.log(`ℹ️  ${constantName} address is already target address: ${newAddress}`);
                }
            } else {
                console.log(`⚠️  ${constantName} constant declaration not found`);
            }
        }

        // Write back to file
        fs.writeFileSync(contractPath, contractContent, 'utf8');
        console.log(`\n🎉 Successfully updated contract file: ${contractPath}`);
        
    } catch (error) {
        console.error('Error occurred while replacing addresses:', error);
    }
}

/**
 * Create address configuration file template for new chain
 * @param {string} chainName - Chain name
 */
function createAddressTemplate(chainName) {
    const addressFilePath = path.join(__dirname, 'addresses', `${chainName}.json`);
    
    if (fs.existsSync(addressFilePath)) {
        console.log(`Address file already exists: ${addressFilePath}`);
        return;
    }

    const template = {
        "POOL_MANAGER": "0x0000000000000000000000000000000000000000",
        "STATE_VIEW": "0x0000000000000000000000000000000000000000", 
        "POSITION_MANAGER": "0x0000000000000000000000000000000000000000",
        "FLUID_LITE_DEX": "0x0000000000000000000000000000000000000000",
        "FLUID_LITE_DEPLOYER_CONTRACT": "0x0000000000000000000000000000000000000000",
        "FLUID_LIQUIDITY": "0x0000000000000000000000000000000000000000",
        "FLUID_DEX_V2": "0x0000000000000000000000000000000000000000"
    };

    fs.writeFileSync(addressFilePath, JSON.stringify(template, null, 2), 'utf8');
    console.log(`✅ Created address configuration template: ${addressFilePath}`);
}

/**
 * Show usage help
 */
function showHelp() {
    console.log(`
Usage:
  node scripts/replace_addresses.js <command> [chainName]

Commands:
  replace <chainName>  - Replace constants in contract with specified chain address configuration
  create <chainName>   - Create address configuration file template for specified chain
  help                 - Show this help information

Examples:
  node scripts/replace_addresses.js replace eth
  node scripts/replace_addresses.js create bsc
  node scripts/replace_addresses.js help
    `);
}

// Main function
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
                console.error('Error: Please specify chain name');
                showHelp();
                return;
            }
            await replaceAddresses(chainName);
            break;
            
        case 'create':
            if (!chainName) {
                console.error('Error: Please specify chain name');
                showHelp();
                return;
            }
            createAddressTemplate(chainName);
            break;
            
        case 'help':
            showHelp();
            break;
            
        default:
            console.error(`Error: Unknown command "${command}"`);
            showHelp();
    }
}

// Run main function
if (require.main === module) {
    main().catch(console.error);
}

module.exports = {
    replaceAddresses,
    createAddressTemplate
};
