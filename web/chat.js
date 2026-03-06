(() => {
    const STUN_SERVERS = [
        {urls: 'stun:stun.l.google.com:19302'},
        {urls: 'stun:stun1.l.google.com:19302'}
    ];

    let ws = null;
    let pc = null;
    let dataChannel = null;
    let role = null;
    let localName = '';
    let peerName = '';

    const $ = document.getElementById.bind(document);

    const sendSignaling = (msg) => {
        if (ws?.readyState === WebSocket.OPEN) {
            ws.send(JSON.stringify(msg));
        }
    };

    const displayMessage = (sender, text) => {
        const el = $('chat-messages');
        const div = document.createElement('div');
        div.className = 'chat-msg';
        const name = document.createElement('span');
        name.className = `chat-msg-name${sender === 'You' ? ' chat-msg-you' : ''}`;
        name.textContent = `${sender}: `;
        div.append(name, text);
        el.append(div);
        el.scrollTop = el.scrollHeight;
    };

    const displaySystemMessage = (text) => {
        const el = $('chat-messages');
        const div = document.createElement('div');
        div.className = 'chat-msg chat-msg-system';
        div.textContent = text;
        el.append(div);
        el.scrollTop = el.scrollHeight;
    };

    const updateStatus = (text) => {
        $('chat-status').textContent = text;
    };

    const showRoomCode = (code) => {
        $('chat-connect').style.display = 'none';
        $('chat-waiting').style.display = 'block';
        $('chat-room-code').textContent = code;
    };

    const showChatUI = () => {
        $('chat-connect').style.display = 'none';
        $('chat-waiting').style.display = 'none';
        $('chat-messages-view').style.display = 'flex';
        const roleEl = $('chat-role');
        roleEl.textContent = role === 'host' ? 'Host' : 'Watching';
        roleEl.classList.remove('chat-role-hidden');
    };

    const showConnectUI = () => {
        $('chat-messages-view').style.display = 'none';
        $('chat-waiting').style.display = 'none';
        $('chat-connect').style.display = 'block';
        $('chat-messages').innerHTML = '';
        $('chat-role').classList.add('chat-role-hidden');
        updateStatus('');
    };

    const setupDataChannel = (channel) => {
        channel.onopen = () => {
            channel.send(JSON.stringify({type: 'name', name: localName}));
            if (role === 'host') {
                startHostCapture();
                startSyncBroadcast();
            } else if (role === 'guest') {
                startGuestBlock();
            }
        };
        channel.onmessage = (e) => {
            const msg = JSON.parse(e.data);
            if (msg.type === 'name') {
                peerName = msg.name || 'Peer';
                displaySystemMessage(`${peerName} joined.`);
            } else if (msg.type === 'chat') {
                displayMessage(peerName || 'Peer', msg.text);
            } else if (msg.type === 'sync' && role === 'guest') {
                handleSyncMessage(msg.pos);
            } else if (msg.type === 'input' && role === 'guest') {
                const isModifier = (msg.eventType === 'keydown' || msg.eventType === 'keyup') &&
                    ['Control', 'Shift', 'Alt', 'Meta'].includes(msg.key);
                if (guestPaused && !isModifier) {
                    return;
                }
                if (msg.action === 'fullscreen') {
                    Module._ons_toggle_fullscreen();
                } else if (msg.eventType === 'keydown' || msg.eventType === 'keyup') {
                    const evt = new KeyboardEvent(msg.eventType, {
                        key: msg.key, code: msg.code, keyCode: msg.keyCode,
                        bubbles: true
                    });
                    trustedEvents.add(evt);
                    window.dispatchEvent(evt);
                } else {
                    window.sendMouseEvent(msg.eventType, msg.nx, msg.ny, msg.button);
                }
            }
        };
        channel.onclose = () => handleDisconnect();
    };

    const handleDisconnect = () => {
        stopHostCapture();
        stopGuestBlock();
        stopSyncBroadcast();
        guestPaused = false;
        hostPosition = null;
        pc?.close();
        pc = null;
        dataChannel = null;
        ws?.close();
        ws = null;
        role = null;
        peerName = '';
        showConnectUI();
    };

    const createPeerConnection = () => {
        pc = new RTCPeerConnection({iceServers: STUN_SERVERS});

        pc.onicecandidate = ({candidate}) => {
            if (candidate) {
                sendSignaling({type: 'signal', data: {ice: candidate}});
            }
        };

        pc.ondatachannel = ({channel}) => {
            dataChannel = channel;
            setupDataChannel(channel);
        };

        pc.onconnectionstatechange = () => {
            if (pc.connectionState === 'connected') {
                showChatUI();
                displaySystemMessage('Connected!');
            } else if (pc.connectionState === 'disconnected' || pc.connectionState === 'failed') {
                handleDisconnect();
                displaySystemMessage('Connection lost.');
            }
        };
    };

    const handleSignalData = async (data) => {
        if (!pc) {
            return;
        }
        if (data.sdp) {
            await pc.setRemoteDescription(data.sdp);
            if (data.sdp.type === 'offer') {
                const answer = await pc.createAnswer();
                await pc.setLocalDescription(answer);
                sendSignaling({type: 'signal', data: {sdp: pc.localDescription}});
            }
        } else if (data.ice) {
            await pc.addIceCandidate(data.ice);
        }
    };

    const handleSignalingMessage = async (msg) => {
        switch (msg.type) {
            case 'room-created':
                showRoomCode(msg.code);
                break;
            case 'peer-joined': {
                createPeerConnection();
                dataChannel = pc.createDataChannel('chat');
                setupDataChannel(dataChannel);
                const offer = await pc.createOffer();
                await pc.setLocalDescription(offer);
                sendSignaling({type: 'signal', data: {sdp: pc.localDescription}});
                break;
            }
            case 'joined':
                updateStatus('Joined room, connecting...');
                createPeerConnection();
                break;
            case 'signal':
                await handleSignalData(msg.data);
                break;
            case 'peer-left':
                handleDisconnect();
                displaySystemMessage('Peer disconnected.');
                break;
            case 'error':
                updateStatus(`Error: ${msg.message}`);
                break;
        }
    };

    const connectSignaling = (onOpen) => {
        const protocol = location.protocol === 'https:' ? 'wss:' : 'ws:';
        ws = new WebSocket(`${protocol}//${location.host}/ws`);
        ws.onopen = onOpen;
        ws.onmessage = (e) => handleSignalingMessage(JSON.parse(e.data));
        ws.onclose = () => updateStatus('Signaling disconnected');
        ws.onerror = () => updateStatus('Failed to connect to signaling server');
    };

    const hostRoom = () => {
        localName = $('chat-name-input').value.trim() || 'Host';
        connectSignaling(() => {
            role = 'host';
            sendSignaling({type: 'create-room'});
        });
    };

    const joinRoom = (code) => {
        localName = $('chat-name-input').value.trim() || 'Guest';
        connectSignaling(() => {
            role = 'guest';
            updateStatus('Joining...');
            sendSignaling({type: 'join-room', code: code.toUpperCase().trim()});
        });
    };

    const sendChatMessage = (text) => {
        if (dataChannel?.readyState === 'open' && text.trim()) {
            dataChannel.send(JSON.stringify({type: 'chat', text}));
            displayMessage('You', text);
        }
    };

    const sendInput = (eventType, nx, ny, button) => {
        if (dataChannel?.readyState === 'open' && role === 'host') {
            dataChannel.send(JSON.stringify({type: 'input', eventType, nx, ny, button}));
        }
    };

    const sendInputAction = (action) => {
        if (dataChannel?.readyState === 'open' && role === 'host') {
            dataChannel.send(JSON.stringify({type: 'input', action}));
        }
    };

    const sendKeyInput = (eventType, e) => {
        if (dataChannel?.readyState === 'open' && role === 'host') {
            dataChannel.send(JSON.stringify({
                type: 'input', eventType,
                key: e.key, code: e.code, keyCode: e.keyCode
            }));
        }
    };

    let hostListeners = [];
    let guestBlocker = null;
    const trustedEvents = new WeakSet();
    let syncInterval = null;
    let hostPosition = null;
    let guestPaused = false;

    const getScriptPosition = () => {
        if (typeof Module?._ons_get_script_position === 'function') {
            return Module._ons_get_script_position();
        }
        return -1;
    };

    const startSyncBroadcast = () => {
        syncInterval = setInterval(() => {
            if (dataChannel?.readyState === 'open') {
                dataChannel.send(JSON.stringify({type: 'sync', pos: getScriptPosition()}));
            }
        }, 500);
    };

    const stopSyncBroadcast = () => {
        if (syncInterval) {
            clearInterval(syncInterval);
            syncInterval = null;
        }
    };

    const handleSyncMessage = (hostPos) => {
        hostPosition = hostPos;
        const guestPos = getScriptPosition();
        if (guestPos === -1 || hostPos === -1) {
            return;
        }
        if (guestPos > hostPos && !guestPaused) {
            guestPaused = true;
            displaySystemMessage('Syncing...');
        }
        if (guestPos <= hostPos && guestPaused) {
            guestPaused = false;
            displaySystemMessage('Synced.');
        }
    };

    const startHostCapture = () => {
        const canvas = $('canvas');

        const onMouseDown = (e) => {
            const [nx, ny] = window.toNormalizedCoords(e.clientX, e.clientY);
            const button = e.button === 2 ? 2 : 0;
            sendInput(0, nx, ny, button);
        };
        const onMouseUp = (e) => {
            const [nx, ny] = window.toNormalizedCoords(e.clientX, e.clientY);
            const button = e.button === 2 ? 2 : 0;
            sendInput(1, nx, ny, button);
        };
        const onMouseMove = (e) => {
            const [nx, ny] = window.toNormalizedCoords(e.clientX, e.clientY);
            sendInput(2, nx, ny, 0);
        };

        const onTouchStart = (e) => {
            if (e.touches.length === 1) {
                const [nx, ny] = window.toNormalizedCoords(e.touches[0].clientX, e.touches[0].clientY);
                sendInput(2, nx, ny, 0);
                sendInput(0, nx, ny, 0);
            }
        };
        const onTouchEnd = (e) => {
            if (e.changedTouches.length === 1) {
                const [nx, ny] = window.toNormalizedCoords(e.changedTouches[0].clientX, e.changedTouches[0].clientY);
                sendInput(1, nx, ny, 0);
            }
        };
        const onTouchMove = (e) => {
            if (e.touches.length === 1) {
                const [nx, ny] = window.toNormalizedCoords(e.touches[0].clientX, e.touches[0].clientY);
                sendInput(2, nx, ny, 0);
            }
        };

        canvas.addEventListener('mousedown', onMouseDown);
        canvas.addEventListener('mouseup', onMouseUp);
        canvas.addEventListener('mousemove', onMouseMove);
        canvas.addEventListener('touchstart', onTouchStart);
        canvas.addEventListener('touchend', onTouchEnd);
        canvas.addEventListener('touchmove', onTouchMove);

        hostListeners = [
            ['mousedown', onMouseDown],
            ['mouseup', onMouseUp],
            ['mousemove', onMouseMove],
            ['touchstart', onTouchStart],
            ['touchend', onTouchEnd],
            ['touchmove', onTouchMove],
        ];

        const onKeyDown = (e) => {
            if (!document.activeElement?.closest('#chat-panel')) {
                sendKeyInput('keydown', e);
            }
        };
        const onKeyUp = (e) => {
            if (!document.activeElement?.closest('#chat-panel')) {
                sendKeyInput('keyup', e);
            }
        };
        window.addEventListener('keydown', onKeyDown);
        window.addEventListener('keyup', onKeyUp);
        hostListeners.push(
            ['keydown', onKeyDown, window],
            ['keyup', onKeyUp, window],
        );

        const fsBtn = $('btn-fullscreen');
        const menuBtn = $('btn-menu');
        const onFullscreen = () => sendInputAction('fullscreen');
        const onMenu = () => {
            sendInput(0, 0.5, 0.5, 2);
            sendInput(1, 0.5, 0.5, 2);
        };
        fsBtn.addEventListener('click', onFullscreen);
        menuBtn.addEventListener('click', onMenu);
        hostListeners.push(
            ['click', onFullscreen, fsBtn],
            ['click', onMenu, menuBtn],
        );
    };

    const stopHostCapture = () => {
        const canvas = $('canvas');
        for (const [evt, fn, target] of hostListeners) {
            (target || canvas).removeEventListener(evt, fn);
        }
        hostListeners = [];
    };

    const startGuestBlock = () => {
        const canvas = $('canvas');
        guestBlocker = (e) => {
            e.stopImmediatePropagation();
            e.preventDefault();
        };
        for (const evt of ['mousedown', 'mouseup', 'mousemove', 'touchstart', 'touchend', 'touchmove']) {
            canvas.addEventListener(evt, guestBlocker, {capture: true});
        }
    };

    const stopGuestBlock = () => {
        if (!guestBlocker) {
            return;
        }
        const canvas = $('canvas');
        for (const evt of ['mousedown', 'mouseup', 'mousemove', 'touchstart', 'touchend', 'touchmove']) {
            canvas.removeEventListener(evt, guestBlocker, {capture: true});
        }
        guestBlocker = null;
    };

    const interceptKey = (e) => {
        if (document.activeElement?.closest('#chat-panel')) {
            if (e.type === 'keydown' && e.key === 'Enter') {
                if (document.activeElement === $('chat-input')) {
                    $('chat-send-btn').click();
                } else if (document.activeElement === $('chat-code-input')) {
                    $('chat-join-btn').click();
                }
            }
            e.stopImmediatePropagation();
            return;
        }
        if (role === 'guest' && !trustedEvents.has(e)) {
            e.stopImmediatePropagation();
            e.preventDefault();
        }
    };

    for (const evt of ['keydown', 'keyup', 'keypress']) {
        window.addEventListener(evt, interceptKey, true);
    }

    document.addEventListener('DOMContentLoaded', () => {
        const panel = $('chat-panel');
        const codeInput = $('chat-code-input');
        const chatInput = $('chat-input');

        $('chat-toggle').addEventListener('click', () => panel.classList.toggle('chat-hidden'));
        $('chat-host-btn').addEventListener('click', () => hostRoom());
        $('chat-cancel-btn').addEventListener('click', () => handleDisconnect());
        $('chat-disconnect-btn').addEventListener('click', () => handleDisconnect());

        $('chat-join-btn').addEventListener('click', () => {
            const code = codeInput.value.trim();
            if (code) {
                joinRoom(code);
            }
        });

        $('chat-send-btn').addEventListener('click', () => {
            const text = chatInput.value;
            if (text.trim()) {
                sendChatMessage(text);
                chatInput.value = '';
                chatInput.focus();
            }
        });

    });
})();
