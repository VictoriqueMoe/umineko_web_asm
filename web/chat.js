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
    };

    const showConnectUI = () => {
        $('chat-messages-view').style.display = 'none';
        $('chat-waiting').style.display = 'none';
        $('chat-connect').style.display = 'block';
        $('chat-messages').innerHTML = '';
        updateStatus('');
    };

    const setupDataChannel = (channel) => {
        channel.onopen = () => {
            channel.send(JSON.stringify({type: 'name', name: localName}));
        };
        channel.onmessage = (e) => {
            const msg = JSON.parse(e.data);
            if (msg.type === 'name') {
                peerName = msg.name || 'Peer';
                displaySystemMessage(`${peerName} joined.`);
            } else if (msg.type === 'chat') {
                displayMessage(peerName || 'Peer', msg.text);
            }
        };
        channel.onclose = () => handleDisconnect();
    };

    const handleDisconnect = () => {
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

    const interceptKey = (e) => {
        if (document.activeElement?.closest('#chat-panel')) {
            e.stopImmediatePropagation();
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

        for (const input of [codeInput, chatInput]) {
            input.addEventListener('keydown', (e) => {
                if (e.key === 'Enter') {
                    input === codeInput ? $('chat-join-btn').click() : $('chat-send-btn').click();
                }
            });
        }
    });
})();
