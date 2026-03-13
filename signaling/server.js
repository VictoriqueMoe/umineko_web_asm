import {WebSocketServer} from 'ws';
import crypto from 'node:crypto';

const PORT = 9090;
const CHARSET = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
const CODE_LENGTH = 6;
const MAX_ROOMS = 100;
const ROOM_TIMEOUT_MS = 10 * 60 * 1000;

const rooms = new Map();

function generateCode() {
    const bytes = crypto.randomBytes(CODE_LENGTH);
    let code = '';
    for (let i = 0; i < CODE_LENGTH; i++) {
        code += CHARSET[bytes[i] % CHARSET.length];
    }
    if (rooms.has(code)) {
        return generateCode();
    }
    return code;
}

function send(ws, msg) {
    if (ws.readyState === 1) {
        ws.send(JSON.stringify(msg));
    }
}

const wss = new WebSocketServer({port: PORT});

wss.on('connection', function (ws) {
    ws._roomCode = null;
    ws._role = null;

    ws.on('message', function (raw) {
        let msg;
        try {
            msg = JSON.parse(raw);
        } catch (e) {
            return;
        }

        if (msg.type === 'create-room') {
            if (rooms.size >= MAX_ROOMS) {
                send(ws, {type: 'error', message: 'Server full'});
                return;
            }
            const code = generateCode();
            const room = {
                host: ws,
                guest: null,
                timeout: setTimeout(function () {
                    send(ws, {type: 'error', message: 'Room expired'});
                    rooms.delete(code);
                    ws.close();
                }, ROOM_TIMEOUT_MS)
            };
            rooms.set(code, room);
            ws._roomCode = code;
            ws._role = 'host';
            send(ws, {type: 'room-created', code: code});
        } else if (msg.type === 'join-room') {
            const room = rooms.get(msg.code);
            if (!room) {
                send(ws, {type: 'error', message: 'Room not found'});
                return;
            }
            if (room.guest) {
                send(ws, {type: 'error', message: 'Room full'});
                return;
            }
            clearTimeout(room.timeout);
            room.guest = ws;
            ws._roomCode = msg.code;
            ws._role = 'guest';
            send(ws, {type: 'joined'});
            send(room.host, {type: 'peer-joined'});
        } else if (msg.type === 'signal') {
            const room = rooms.get(ws._roomCode);
            if (!room) {
                return;
            }
            const target = (ws._role === 'host') ? room.guest : room.host;
            if (target) {
                send(target, {type: 'signal', data: msg.data});
            }
        }
    });

    ws.on('close', function () {
        if (!ws._roomCode) {
            return;
        }
        const room = rooms.get(ws._roomCode);
        if (!room) {
            return;
        }
        if (ws._role === 'host') {
            clearTimeout(room.timeout);
            if (room.guest) {
                send(room.guest, {type: 'peer-left'});
                room.guest._roomCode = null;
            }
            rooms.delete(ws._roomCode);
        } else if (ws._role === 'guest') {
            room.guest = null;
            send(room.host, {type: 'peer-left'});
        }
    });
});

console.log('Signaling server listening on port ' + PORT);
