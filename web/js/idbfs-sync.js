(() => {
    let syncing = false;

    const sync = () => {
        if (syncing) {
            return;
        }
        syncing = true;
        try {
            FS.syncfs(false, (err) => {
                syncing = false;
                if (err) {
                    console.warn('IDBFS sync error:', err);
                }
            });
        } catch (e) {
            syncing = false;
        }
    };

    setInterval(sync, 5000);
    window.addEventListener('beforeunload', sync);
})();
