(() => {
    const origGetContext = HTMLCanvasElement.prototype.getContext;
    HTMLCanvasElement.prototype.getContext = function (type, attrs) {
        if (type === 'webgl' || type === 'webgl2') {
            attrs = attrs || {};
            attrs.preserveDrawingBuffer = true;
        }
        return origGetContext.call(this, type, attrs);
    };

    Game.initCanvas = () => {
        document.getElementById('loading').classList.add('hidden');
        const canvas = document.getElementById('canvas');

        const originalAspect = canvas.width / canvas.height;

        const fitCanvas = () => {
            if (document.fullscreenElement) {
                return;
            }
            const vpW = window.innerWidth;
            const vpH = window.innerHeight;
            let w, h;
            if (vpW / vpH > originalAspect) {
                h = vpH;
                w = Math.round(vpH * originalAspect);
            } else {
                w = vpW;
                h = Math.round(vpW / originalAspect);
            }
            canvas.style.width = w + 'px';
            canvas.style.height = h + 'px';
        };

        fitCanvas();
        window.addEventListener('resize', fitCanvas);
        document.addEventListener('fullscreenchange', () => {
            if (!document.fullscreenElement) {
                setTimeout(fitCanvas, 100);
            }
        });

        const toNormalizedCoords = (clientX, clientY) => {
            const rect = canvas.getBoundingClientRect();
            return [
                (clientX - rect.left) / rect.width,
                (clientY - rect.top) / rect.height
            ];
        };

        const sendMouseEvent = (type, x, y, button) => {
            Module._ons_mouse_event(type, x, y, button);
        };

        window.toNormalizedCoords = toNormalizedCoords;
        window.sendMouseEvent = sendMouseEvent;

        canvas.addEventListener('touchstart', (e) => {
            e.preventDefault();
            e.stopImmediatePropagation();
            if (e.touches.length === 1) {
                const touch = e.touches[0];
                const coords = toNormalizedCoords(touch.clientX, touch.clientY);
                sendMouseEvent(2, coords[0], coords[1], 0);
                sendMouseEvent(0, coords[0], coords[1], 0);
            }
        }, {passive: false, capture: true});

        canvas.addEventListener('touchend', (e) => {
            e.preventDefault();
            e.stopImmediatePropagation();
            if (e.changedTouches.length === 1) {
                const touch = e.changedTouches[0];
                const coords = toNormalizedCoords(touch.clientX, touch.clientY);
                sendMouseEvent(1, coords[0], coords[1], 0);
            }
        }, {passive: false, capture: true});

        canvas.addEventListener('touchmove', (e) => {
            e.preventDefault();
            e.stopImmediatePropagation();
            if (e.touches.length === 1) {
                const touch = e.touches[0];
                const coords = toNormalizedCoords(touch.clientX, touch.clientY);
                sendMouseEvent(2, coords[0], coords[1], 0);
            }
        }, {passive: false, capture: true});

        const btnFullscreen = document.getElementById('btn-fullscreen');
        const btnMenu = document.getElementById('btn-menu');

        const handleFullscreen = (e) => {
            e.preventDefault();
            e.stopPropagation();
            Module._ons_toggle_fullscreen();
        };

        const handleMenu = (e) => {
            e.preventDefault();
            e.stopPropagation();
            sendMouseEvent(0, 0.5, 0.5, 2);
            sendMouseEvent(1, 0.5, 0.5, 2);
        };

        btnFullscreen.addEventListener('touchstart', handleFullscreen, {passive: false});
        btnFullscreen.addEventListener('click', handleFullscreen);
        btnMenu.addEventListener('touchstart', handleMenu, {passive: false});
        btnMenu.addEventListener('click', handleMenu);
    };
})();
