(() => {
    const EAGER_PATTERNS = [
        /^default\.cfg$/,
        /^en\.file$/,
        /^chiru\.file$/,
        /^ru\.file$/,
        /^game\.hash$/,
        /^fonts\//
    ];

    window.gameFileSet = new Set();

    const shouldEagerLoad = (path) => {
        for (let i = 0; i < EAGER_PATTERNS.length; i++) {
            if (EAGER_PATTERNS[i].test(path)) {
                return true;
            }
        }
        return false;
    };

    const eagerFetch = (vfsPath, url) => {
        Module.addRunDependency('file:' + vfsPath);
        const xhr = new XMLHttpRequest();
        xhr.open('GET', url, true);
        xhr.responseType = 'arraybuffer';
        xhr.onload = () => {
            if (xhr.status === 200) {
                FS.writeFile(vfsPath, new Uint8Array(xhr.response));
            } else {
                console.warn('Failed to fetch ' + url + ' (status ' + xhr.status + ')');
            }
            Module.removeRunDependency('file:' + vfsPath);
        };
        xhr.onerror = () => {
            console.warn('Failed to fetch ' + url);
            Module.removeRunDependency('file:' + vfsPath);
        };
        xhr.send();
    };

    const eagerLoadLocal = (vfsPath, relativePath) => {
        Module.addRunDependency('file:' + vfsPath);
        window.readLocalFile(relativePath).then((data) => {
            if (data) {
                FS.writeFile(vfsPath, data);
            }
            Module.removeRunDependency('file:' + vfsPath);
        }).catch(() => {
            Module.removeRunDependency('file:' + vfsPath);
        });
    };

    Game.populateVFS = async (manifest, isRemote, loadingEl) => {
        const dirs = manifest.dirs;
        const files = manifest.files;
        const emptyStub = new Uint8Array(0);

        loadingEl.textContent = 'Setting up filesystem...';
        await new Promise(r => setTimeout(r, 0));

        for (let i = 0; i < dirs.length; i++) {
            try {
                FS.mkdirTree('/game/' + dirs[i]);
            } catch (e) {
            }
            if (i % 2000 === 0 && i > 0) {
                loadingEl.textContent = 'Creating directories... ' + Math.round((i / dirs.length) * 100) + '%';
                await new Promise(r => setTimeout(r, 0));
            }
        }

        let eagerCount = 0;
        let lazyCount = 0;

        for (let i = 0; i < files.length; i++) {
            const filePath = files[i];
            const vfsPath = '/game/' + filePath;

            if (shouldEagerLoad(filePath)) {
                if (isRemote) {
                    eagerLoadLocal(vfsPath, filePath);
                } else {
                    eagerFetch(vfsPath, '/game/' + filePath);
                }
                eagerCount++;
            } else {
                try {
                    FS.writeFile(vfsPath, emptyStub);
                    window.gameFileSet.add(vfsPath);
                    lazyCount++;
                } catch (e) {
                    console.warn('Failed to create stub: ' + vfsPath, e);
                }
            }

            if (i % 5000 === 0 && i > 0) {
                loadingEl.textContent = 'Registering files... ' + Math.round((i / files.length) * 100) + '%';
                await new Promise(r => setTimeout(r, 0));
            }
        }

        console.log('Filesystem setup: ' + eagerCount + ' eager, ' + lazyCount + ' lazy stubs');
        loadingEl.textContent = 'Loading game data (' + eagerCount + ' files)...';
    };
})();
