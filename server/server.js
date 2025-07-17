// ARapp2
const WebSocket = require('ws');
const http = require('http');

const server = http.createServer();
const wss = new WebSocket.Server({ server });

const clients = new Map();

class Client {
    constructor(ws, role, id) {
        this.ws = ws;
        this.role = role;
        this.id = id;
        this.isAlive = true;
        this.audioActive = false;
    }

    send(data) {
        if (this.ws.readyState === WebSocket.OPEN) {
            this.ws.send(data, { binary: true });
        }
    }

    sendJSON(obj) {
        this.send(JSON.stringify(obj));
    }
}

function heartbeat() {
    this.isAlive = true;
}

wss.on('connection', (ws) => {
    console.log('New connection established');
    
    ws.isAlive = true;
    ws.on('pong', heartbeat);
    
    let client = null;

    ws.on('message', (message) => {
        try {
            if (message instanceof Buffer && message.length > 6) {
                const prefix = message.slice(0, 6).toString();
                
                if (prefix === 'AUDIO:') {
                    handleAudioData(client, message.slice(6));
                    return;
                }
                
                if (isImageData(message)) {
                    handleImageData(client, message);
                    return;
                }
            }

            const data = JSON.parse(message);
            
            switch (data.type) {
                case 'register':
                    client = new Client(ws, data.role, data.id);
                    clients.set(ws, client);
                    
                    client.sendJSON({
                        type: 'registered',
                        role: data.role,
                        id: data.id
                    });
                    
                    broadcastStatus();
                    console.log(`Client registered as ${data.role} with ID: ${data.id}`);
                    break;

                case 'drawing':
                    handleDrawingMessage(client, data);
                    break;

                case 'clear_drawings':
                    broadcastToRole('user', message);
                    console.log('Clear drawings command sent');
                    break;

                case 'audio_command':
                    handleAudioCommand(client, data);
                    break;

                default:
                    console.log('Unknown message type:', data.type);
            }
        } catch (err) {
            console.error('Error processing message:', err);
        }
    });

    ws.on('close', () => {
        console.log('Connection closed');
        if (client) {
            clients.delete(ws);
            broadcastStatus();
        }
    });

    ws.on('error', (err) => {
        console.error('WebSocket error:', err);
    });
});

function handleAudioData(sender, audioData) {
    if (!sender || !sender.audioActive) return;
    
    const targetRole = sender.role === 'user' ? 'aid' : 'user';
    
    const audioMessage = Buffer.concat([
        Buffer.from('AUDIO:'),
        audioData
    ]);
    
    clients.forEach((client) => {
        if (client.role === targetRole && client.audioActive) {
            client.send(audioMessage);
        }
    });
}

function handleAudioCommand(sender, data) {
    if (!sender) return;
    
    switch (data.command) {
        case 'audio_start':
            sender.audioActive = true;
            const targetRole = sender.role === 'user' ? 'aid' : 'user';
            
            broadcastToRole(targetRole, JSON.stringify({
                type: 'audio_command',
                command: 'audio_start'
            }));
            
            console.log(`Audio started by ${sender.role}`);
            break;
            
        case 'audio_end':
            sender.audioActive = false;
            const endTargetRole = sender.role === 'user' ? 'aid' : 'user';
            
            broadcastToRole(endTargetRole, JSON.stringify({
                type: 'audio_command',
                command: 'audio_end'
            }));
            
            console.log(`Audio ended by ${sender.role}`);
            break;
    }
}

function handleImageData(sender, imageData) {
    if (!sender || sender.role !== 'user') return;
    
    broadcastToRole('aid', imageData);
}

function handleDrawingMessage(sender, data) {
    if (!sender || sender.role !== 'aid') return;
    
    broadcastToRole('user', JSON.stringify(data));
    console.log(`Drawing ${data.action} for ID: ${data.drawingId}`);
}

function isImageData(data) {
    if (data.length < 4) return false;
    
    const jpegHeader = data[0] === 0xFF && data[1] === 0xD8;
    const pngHeader = data[0] === 0x89 && data[1] === 0x50 && data[2] === 0x4E && data[3] === 0x47;
    
    return jpegHeader || pngHeader;
}

function broadcastToRole(role, data) {
    clients.forEach((client) => {
        if (client.role === role) {
            client.send(data);
        }
    });
}

function broadcastStatus() {
    const status = {
        type: 'status',
        connectedUsers: Array.from(clients.values()).filter(c => c.role === 'user').length,
        connectedAids: Array.from(clients.values()).filter(c => c.role === 'aid').length
    };
    
    clients.forEach((client) => {
        client.sendJSON(status);
    });
}

const interval = setInterval(() => {
    wss.clients.forEach((ws) => {
        if (ws.isAlive === false) {
            console.log('Terminating inactive connection');
            return ws.terminate();
        }
        
        ws.isAlive = false;
        ws.ping();
    });
}, 30000);

wss.on('close', () => {
    clearInterval(interval);
});

const PORT = process.env.PORT || 3000;
server.listen(PORT, '0.0.0.0', () => {
    console.log(`WebSocket server is running on port ${PORT}`);
    console.log(`Connect via ws://YOUR_IP_ADDRESS:${PORT}`);
});
