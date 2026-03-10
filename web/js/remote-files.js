(() => {
    const REQUIRED_FILES = ['default.cfg', 'chiru.file'];

    const scanDirectoryHandle = async (handle, prefix, counter) => {
        if (!counter) {
            counter = {count: 0};
        }
        const dirs = [];
        const files = [];
        const statusEl = document.getElementById('scan-status');
        for await (const entry of handle.values()) {
            const path = prefix ? prefix + '/' + entry.name : entry.name;
            if (entry.kind === 'directory') {
                dirs.push(path);
                const sub = await scanDirectoryHandle(entry, path, counter);
                dirs.push.apply(dirs, sub.dirs);
                files.push.apply(files, sub.files);
            } else {
                files.push(path);
                counter.count++;
                if (counter.count % 1000 === 0) {
                    statusEl.textContent = 'Scanned ' + counter.count + ' files...';
                    await new Promise(r => setTimeout(r, 0));
                }
            }
        }
        return {dirs, files};
    };

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
        const missing = REQUIRED_FILES.filter(f => !manifest.files.includes(f));
        if (missing.length > 0) {
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

        btnPick.addEventListener('click', async () => {
            pickerError.classList.add('hidden');

            if (window.showDirectoryPicker) {
                try {
                    const handle = await window.showDirectoryPicker({mode: 'read'});

                    scanStatus.textContent = 'Scanning game files...';
                    scanStatus.classList.remove('hidden');
                    btnPick.disabled = true;

                    const manifest = await scanDirectoryHandle(handle, '');

                    window.readLocalFile = async (relativePath) => {
                        try {
                            const parts = relativePath.split('/');
                            let current = handle;
                            for (let i = 0; i < parts.length - 1; i++) {
                                current = await current.getDirectoryHandle(parts[i]);
                            }
                            const fh = await current.getFileHandle(parts[parts.length - 1]);
                            const file = await fh.getFile();
                            return new Uint8Array(await file.arrayBuffer());
                        } catch (e) {
                            console.warn('Failed to read local file: ' + relativePath, e);
                            return null;
                        }
                    };

                    onFilesReady(manifest);
                } catch (e) {
                    if (e.name !== 'AbortError') {
                        console.error('Directory picker error:', e);
                        pickerError.textContent = 'Failed to open folder. Please try again.';
                        pickerError.classList.remove('hidden');
                    }
                    btnPick.disabled = false;
                    scanStatus.classList.add('hidden');
                }
            } else {
                folderInput.click();
            }
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
