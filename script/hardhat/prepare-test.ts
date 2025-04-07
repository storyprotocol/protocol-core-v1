import fs from 'fs';
import path from 'path';

async function main() {
    // copy mock contracts to contracts directory
    // this is a workaround to avoid the issue that the mock contracts are not found by hardhat
    // because the mock contracts are in the foundry test directory
    const mockFilesPath = [
        'test/foundry/mocks/module/MockLicenseTemplate.sol',
    ];

    for (const filePath of mockFilesPath) {
        const fileName = filePath.split('/').pop() || '';
        const sourceFile = path.join(__dirname, '..', '..', filePath);
        const targetDir = path.join(__dirname, '..', '..', 'contracts');
        const targetFile = path.join(targetDir, fileName);

        // ensure target directory exists
        if (!fs.existsSync(targetDir)) {
            fs.mkdirSync(targetDir, { recursive: true });
        }

        // check if source file exists
        if (!fs.existsSync(sourceFile)) {
            throw new Error(`Source file not found: ${sourceFile}`);
        }

        // copy file
        fs.copyFileSync(sourceFile, targetFile);
        console.log(`Mock contract has been copied from ${sourceFile} to ${targetFile}`);
    }

}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
