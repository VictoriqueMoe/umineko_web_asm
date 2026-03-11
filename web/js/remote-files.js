(() => {
    const REQUIRED_FILES = ['default.cfg', 'chiru.file'];

    const buildManifestFromFileList = async (fileList, statusEl) => {
        const dirSet = new Set();
        const files = [];
        const fileMap = {};

        for (let i = 0; i < fileList.length; i++) {
            const file = fileList[i];
            const parts = file.webkitRelativePath.split('/');
            parts.shift();
            const path = parts.join('/');

            if (!path) {
                continue;
            }

            files.push(path);
            fileMap[path] = file;

            for (let j = 1; j < parts.length; j++) {
                dirSet.add(parts.slice(0, j).join('/'));
            }

            if (i % 5000 === 0 && i > 0 && statusEl) {
                statusEl.textContent = 'Processing files... ' + Math.round((i / fileList.length) * 100) + '%';
                await new Promise(r => setTimeout(r, 0));
            }
        }

        return {dirs: Array.from(dirSet), files, fileMap};
    };

    const validateManifest = (manifest) => {
        const lowerFiles = new Set(manifest.files.map(f => f.toLowerCase()));
        const missing = REQUIRED_FILES.filter(f => !lowerFiles.has(f));
        if (missing.length > 0) {
            const topLevel = manifest.files.filter(f => !f.includes('/'));
            console.warn('Validation failed. Top-level files found:', topLevel);
            return 'This does not appear to be a valid Umineko game folder (missing ' + missing.join(', ') + ').';
        }
        return null;
    };

    Game.setupRemoteMode = (loadingEl, onComplete) => {
        loadingEl.style.display = 'none';
        const pickerScreen = document.getElementById('file-picker-screen');
        pickerScreen.style.display = 'flex';

        const btnPick = document.getElementById('btn-pick-folder');
        const folderInput = document.getElementById('folder-input');
        const scanStatus = document.getElementById('scan-status');
        const pickerError = document.getElementById('picker-error');

        const onFilesReady = async (manifest) => {
            const error = validateManifest(manifest);
            if (error) {
                pickerError.textContent = error;
                pickerError.classList.remove('hidden');
                scanStatus.classList.add('hidden');
                btnPick.disabled = false;
                return;
            }

            pickerScreen.style.display = 'none';
            loadingEl.style.display = '';

            await Game.populateVFS(manifest, true, loadingEl);

            if (onComplete) {
                onComplete();
            }
            Module.removeRunDependency('manifest');
        };

        btnPick.addEventListener('click', () => {
            pickerError.classList.add('hidden');
            scanStatus.textContent = 'Scanning game files...';
            scanStatus.classList.remove('hidden');
            btnPick.disabled = true;
            folderInput.click();
        });

        folderInput.addEventListener('cancel', () => {
            scanStatus.classList.add('hidden');
            btnPick.disabled = false;
        });

        folderInput.addEventListener('change', () => {
            const fileList = folderInput.files;
            if (!fileList || fileList.length === 0) {
                return;
            }

            scanStatus.textContent = 'Processing ' + fileList.length + ' files...';
            scanStatus.classList.remove('hidden');
            btnPick.disabled = true;

            setTimeout(async () => {
                const manifest = await buildManifestFromFileList(fileList, scanStatus);

                window.readLocalFile = async (relativePath) => {
                    const file = manifest.fileMap[relativePath];
                    if (!file) {
                        console.warn('Local file not found: ' + relativePath);
                        return null;
                    }
                    return new Uint8Array(await file.arrayBuffer());
                };

                onFilesReady(manifest);
            }, 50);
        });
    };
})();
