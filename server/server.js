const express = require('express');
const WebSocket = require('ws');
const http = require('http');

const app = express();
const server = http.createServer(app);
const wss = new WebSocket.Server({ server });
const clients = {
    users: new Set(),
    aids: new Set()
};

const drawingHistory = [];
const MAX_DRAWING_HISTORY = 100;
wss.on('connection', (ws) => {
    console.log('New client connected');
    
    let clientType = null;
    let clientId = null;

    ws.on('message', (message) => {
        try {
            if (message.toString().startsWith('{')) {
                const data = JSON.parse(message);
                
                switch (data.type) {
                    case 'register':
                        clientType = data.role;
                        clientId = data.id;
                        
                        if (clientType === 'user') {
                            clients.users.add(ws);
                            console.log(`User registered: ${clientId}`);
                            if (drawingHistory.length > 0) {
                                ws.send(JSON.stringify({
                                    type: 'drawing_history',
                                    drawings: drawingHistory
                                }));
                            }
                        } else if (clientType === 'aid') {
                            clients.aids.add(ws);
                            console.log(`Aid registered: ${clientId}`);
                        }
                        
                        ws.send(JSON.stringify({ 
                            type: 'registered', 
                            role: clientType,
                            connectedUsers: clients.users.size,
                            connectedAids: clients.aids.size
                        }));
                        break;
                        
                    case 'drawing':
                        if (clients.aids.has(ws)) {
                            const drawingMessage = JSON.stringify(data);
                            if (data.action === 'add') {
                                drawingHistory.push(data);
                                if (drawingHistory.length > MAX_DRAWING_HISTORY) {
                                    drawingHistory.shift();
                                }
                            }
                            
                            clients.users.forEach((userWs) => {
                                if (userWs.readyState === WebSocket.OPEN) {
                                    userWs.send(drawingMessage);
                                }
                            });
                            
                            console.log(`Drawing action: ${data.action}, ID: ${data.drawingId}`);
                        }
                        break;
                        
                    case 'clear_drawings':
                        drawingHistory.length = 0;
                        const clearMessage = JSON.stringify({ type: 'clear_drawings' });
                        
                        [...clients.users, ...clients.aids].forEach((client) => {
                            if (client.readyState === WebSocket.OPEN) {
                                client.send(clearMessage);
                            }
                        });
                        
                        console.log('Drawings cleared');
                        break;
                }
            } else {
                if (clients.users.has(ws)) {
                    clients.aids.forEach((aidWs) => {
                        if (aidWs.readyState === WebSocket.OPEN) {
                            aidWs.send(message);
                        }
                    });
                }
            }
        } catch (error) {
            console.error('Error processing message:', error);
        }
    });

    ws.on('close', () => {
        console.log('Client disconnected');
        clients.users.delete(ws);
        clients.aids.delete(ws);

        const statusUpdate = JSON.stringify({
            type: 'status',
            connectedUsers: clients.users.size,
            connectedAids: clients.aids.size
        });
        
        [...clients.users, ...clients.aids].forEach((client) => {
            if (client.readyState === WebSocket.OPEN) {
                client.send(statusUpdate);
            }
        });
    });

    ws.on('error', (error) => {
        console.error('WebSocket error:', error);
    });
});

app.get('/health', (req, res) => {
    res.json({ 
        status: 'ok',
        connectedUsers: clients.users.size,
        connectedAids: clients.aids.size,
        drawingHistorySize: drawingHistory.length
    });
});

const PORT = process.env.PORT || 3000;
const HOST = '0.0.0.0';
server.listen(PORT, HOST, () => {
    console.log(`Server running on http://${HOST}:${PORT}`);
});