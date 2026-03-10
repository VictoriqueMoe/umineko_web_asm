(() => {
    const fetchServerManifest = (loadingEl, onComplete) => {
        const xhr = new XMLHttpRequest();
        xhr.open('GET', '/manifest.json', true);
        xhr.responseType = 'json';
        xhr.onload = async () => {
            if (xhr.status !== 200 || !xhr.response) {
                console.error('Failed to load manifest');
                if (onComplete) {
                    onComplete();
                }
                Module.removeRunDependency('manifest');
                return;
            }

            await Game.populateVFS(xhr.response, false, loadingEl);

            if (onComplete) {
                onComplete();
            }
            Module.removeRunDependency('manifest');
        };
        xhr.onerror = () => {
            console.error('Failed to fetch manifest');
            if (onComplete) {
                onComplete();
            }
            Module.removeRunDependency('manifest');
        };
        xhr.send();
    };

    Game.setupGameFiles = (onComplete) => {
        Module.addRunDependency('manifest');
        const loadingEl = document.getElementById('loading');

        const xhr = new XMLHttpRequest();
        xhr.open('GET', '/config.json', true);
        xhr.responseType = 'json';
        xhr.onload = () => {
            const mode = (xhr.response && xhr.response.hostingMode) || 'local';
            if (mode === 'remote') {
                Game.setupRemoteMode(loadingEl, onComplete);
            } else {
                fetchServerManifest(loadingEl, onComplete);
            }
        };
        xhr.onerror = () => {
            fetchServerManifest(loadingEl, onComplete);
        };
        xhr.send();
    };
})();
