(() => {
    let fetchName = 'asset';

    window.showFetchIndicator = (name) => {
        fetchName = name || 'asset';
        document.getElementById('fetch-text').textContent = 'Loading ' + fetchName + '...';
        document.getElementById('fetch-bar').style.width = '0%';
        document.getElementById('fetch-indicator').style.display = 'block';
    };

    window.hideFetchIndicator = () => {
        document.getElementById('fetch-indicator').style.display = 'none';
    };

    window.updateFetchProgress = (received, total) => {
        const pct = Math.round((received / total) * 100);
        document.getElementById('fetch-text').textContent = 'Loading ' + fetchName + '... ' + pct + '%';
        document.getElementById('fetch-bar').style.width = pct + '%';
    };
})();
