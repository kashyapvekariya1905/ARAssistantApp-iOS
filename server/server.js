
// const WebSocket = require('ws');
// const http = require('http');

// const server = http.createServer();
// const wss = new WebSocket.Server({ server });

// const clients = new Map();

// class Client {
//     constructor(ws, role, id) {
//         this.ws = ws;
//         this.role = role;
//         this.id = id;
//         this.isAlive = true;
//         this.audioActive = false;
//     }

//     send(data) {
//         if (this.ws.readyState === WebSocket.OPEN) {
//             try {
//                 this.ws.send(data, { binary: true });
//             } catch (error) {
//                 console.error(`Error sending to client ${this.id}:`, error);
//             }
//         }
//     }

//     sendJSON(obj) {
//         this.send(JSON.stringify(obj));
//     }
// }

// function heartbeat() {
//     this.isAlive = true;
// }

// wss.on('connection', (ws) => {
//     console.log('New connection established');
    
//     ws.isAlive = true;
//     ws.on('pong', heartbeat);
    
//     let client = null;

//     ws.on('message', (message) => {
//         try {
//             if (message instanceof Buffer) {
//                 if (message.length > 6) {
//                     const prefix = message.slice(0, 6).toString();
                    
//                     if (prefix === 'AUDIO:') {
//                         handleAudioData(client, message.slice(6));
//                         return;
//                     }
//                 }
                
//                 if (message.length > 9) {
//                     const prefix = message.slice(0, 9).toString();
                    
//                     if (prefix === 'FEEDBACK:') {
//                         handleFeedbackData(client, message);
//                         return;
//                     }
//                 }
                
//                 if (isImageData(message)) {
//                     handleImageData(client, message);
//                     return;
//                 }
//             }

//             const data = JSON.parse(message);
            
//             switch (data.type) {
//                 case 'register':
//                     client = new Client(ws, data.role, data.id);
//                     clients.set(ws, client);
                    
//                     client.sendJSON({
//                         type: 'registered',
//                         role: data.role,
//                         id: data.id
//                     });
                    
//                     broadcastStatus();
//                     console.log(`Client registered as ${data.role} with ID: ${data.id}`);
//                     break;

//                 case 'drawing':
//                     handleDrawingMessage(client, data);
//                     break;

//                 case 'clear_drawings':
//                     const clearMessage = JSON.stringify({ type: 'clear_drawings' });
//                     clients.forEach((c) => {
//                         c.send(clearMessage);
//                     });
//                     // console.log('Clear drawings command sent to all clients');
//                     break;

//                 case 'audio_command':
//                     handleAudioCommand(client, data);
//                     break;

//                 default:
//                     // console.log('Unknown message type:', data.type);
//             }
//         } catch (err) {
//             console.error('Error processing message:', err);
//         }
//     });

//     ws.on('close', () => {
//         console.log('Connection closed');
//         if (client) {
//             if (client.audioActive) {
//                 const targetRole = client.role === 'user' ? 'aid' : 'user';
//                 broadcastToRole(targetRole, JSON.stringify({
//                     type: 'audio_command',
//                     command: 'audio_end'
//                 }));
//             }
//             clients.delete(ws);
//             broadcastStatus();
//         }
//     });

//     ws.on('error', (err) => {
//         console.error('WebSocket error:', err);
//     });
// });

// function handleAudioData(sender, audioData) {
//     if (!sender || !sender.audioActive) return;
    
//     const targetRole = sender.role === 'user' ? 'aid' : 'user';
    
//     const audioMessage = Buffer.concat([
//         Buffer.from('AUDIO:'),
//         audioData
//     ]);
    
//     let sentCount = 0;
//     clients.forEach((client) => {
//         if (client.role === targetRole && client.audioActive) {
//             client.send(audioMessage);
//             sentCount++;
//         }
//     });
// }

// function handleFeedbackData(sender, feedbackData) {
//     if (!sender || sender.role !== 'user') return;
    
//     let sentCount = 0;
//     clients.forEach((client) => {
//         if (client.role === 'aid') {
//             client.send(feedbackData);
//             sentCount++;
//         }
//     });
// }

// function handleAudioCommand(sender, data) {
//     if (!sender) return;
    
//     switch (data.command) {
//         case 'audio_start':
//             sender.audioActive = true;
//             const targetRole = sender.role === 'user' ? 'aid' : 'user';
            
//             broadcastToRole(targetRole, JSON.stringify({
//                 type: 'audio_command',
//                 command: 'audio_start'
//             }));
            
//             console.log(`Audio started by ${sender.role}`);
//             break;
            
//         case 'audio_end':
//             sender.audioActive = false;
//             const endTargetRole = sender.role === 'user' ? 'aid' : 'user';
            
//             broadcastToRole(endTargetRole, JSON.stringify({
//                 type: 'audio_command',
//                 command: 'audio_end'
//             }));
            
//             console.log(`Audio ended by ${sender.role}`);
//             break;
//     }
// }

// function handleImageData(sender, imageData) {
//     if (!sender || sender.role !== 'user') return;
    
//     let sentCount = 0;
//     clients.forEach((client) => {
//         if (client.role === 'aid') {
//             client.send(imageData);
//             sentCount++;
//         }
//     });
// }

// function handleDrawingMessage(sender, data) {
//     if (!sender || sender.role !== 'aid') return;
    
//     broadcastToRole('user', JSON.stringify(data));
// }

// function isImageData(data) {
//     if (data.length < 4) return false;
    
//     const jpegHeader = data[0] === 0xFF && data[1] === 0xD8;
//     const pngHeader = data[0] === 0x89 && data[1] === 0x50 && data[2] === 0x4E && data[3] === 0x47;
    
//     return jpegHeader || pngHeader;
// }

// function broadcastToRole(role, data) {
//     let sentCount = 0;
//     clients.forEach((client) => {
//         if (client.role === role) {
//             client.send(data);
//             sentCount++;
//         }
//     });
// }

// function broadcastStatus() {
//     const status = {
//         type: 'status',
//         connectedUsers: Array.from(clients.values()).filter(c => c.role === 'user').length,
//         connectedAids: Array.from(clients.values()).filter(c => c.role === 'aid').length
//     };
    
//     clients.forEach((client) => {
//         client.sendJSON(status);
//     });
// }

// const interval = setInterval(() => {
//     wss.clients.forEach((ws) => {
//         if (ws.isAlive === false) {
//             console.log('Terminating inactive connection');
//             return ws.terminate();
//         }
        
//         ws.isAlive = false;
//         ws.ping();
//     });
// }, 30000);

// wss.on('close', () => {
//     clearInterval(interval);
// });

// const PORT = process.env.PORT || 3000;
// server.listen(PORT, '0.0.0.0', () => {
//     console.log(`WebSocket server running on port ${PORT}`);
// });
























const WebSocket = require('ws');
const http = require('http');

// Create HTTP server and WebSocket server instance
const server = http.createServer();
const wss = new WebSocket.Server({ server });

// Map to store all connected clients with their WebSocket as key
const clients = new Map();

/**
 * Client class represents a connected user or aid device
 * Manages the WebSocket connection and client metadata
 */
class Client {
    constructor(ws, role, id) {
        this.ws = ws;           // WebSocket connection
        this.role = role;       // 'user' or 'aid' - determines client type
        this.id = id;           // Unique client identifier
        this.isAlive = true;    // For heartbeat/ping-pong mechanism
        this.audioActive = false; // Whether this client is in an active audio call
    }

    /**
     * Safely sends binary data to the client
     * Checks connection state before sending to prevent errors
     * @param {Buffer|String} data - Data to send
     */
    send(data) {
        if (this.ws.readyState === WebSocket.OPEN) {
            try {
                this.ws.send(data, { binary: true });
            } catch (error) {
                console.error(`Error sending to client ${this.id}:`, error);
            }
        }
    }

    /**
     * Sends JSON data by stringifying the object
     * @param {Object} obj - Object to send as JSON
     */
    sendJSON(obj) {
        this.send(JSON.stringify(obj));
    }
}

/**
 * Heartbeat function for ping-pong mechanism
 * Called when a 'pong' response is received from client
 */
function heartbeat() {
    this.isAlive = true;
}

// MARK: - WebSocket Connection Handler

wss.on('connection', (ws) => {
    console.log('New connection established');
    
    // Initialize connection for heartbeat monitoring
    ws.isAlive = true;
    ws.on('pong', heartbeat);
    
    let client = null; // Will be set when client registers

    // MARK: - Message Handler
    ws.on('message', (message) => {
        try {
            // Handle binary data (audio, images, feedback)
            if (message instanceof Buffer) {
                // Check for audio data prefix
                if (message.length > 6) {
                    const prefix = message.slice(0, 6).toString();
                    
                    if (prefix === 'AUDIO:') {
                        handleAudioData(client, message.slice(6)); // Remove prefix and handle
                        return;
                    }
                }
                
                // Check for feedback data prefix (AR overlay from user to aid)
                if (message.length > 9) {
                    const prefix = message.slice(0, 9).toString();
                    
                    if (prefix === 'FEEDBACK:') {
                        handleFeedbackData(client, message);
                        return;
                    }
                }
                
                // Check if it's image data (JPEG or PNG)
                if (isImageData(message)) {
                    handleImageData(client, message);
                    return;
                }
            }

            // Handle JSON messages (registration, drawing commands, etc.)
            const data = JSON.parse(message);
            
            switch (data.type) {
                case 'register':
                    // New client registration
                    client = new Client(ws, data.role, data.id);
                    clients.set(ws, client);
                    
                    // Confirm registration to client
                    client.sendJSON({
                        type: 'registered',
                        role: data.role,
                        id: data.id
                    });
                    
                    broadcastStatus(); // Update all clients with new connection count
                    console.log(`Client registered as ${data.role} with ID: ${data.id}`);
                    break;

                case 'drawing':
                    // Handle drawing/annotation messages
                    handleDrawingMessage(client, data);
                    break;

                case 'clear_drawings':
                    // Broadcast clear command to all connected clients
                    const clearMessage = JSON.stringify({ type: 'clear_drawings' });
                    clients.forEach((c) => {
                        c.send(clearMessage);
                    });
                    break;

                case 'audio_command':
                    // Handle audio call start/stop commands
                    handleAudioCommand(client, data);
                    break;

                default:
                    // Log unknown message types for debugging
                    // console.log('Unknown message type:', data.type);
            }
        } catch (err) {
            console.error('Error processing message:', err);
        }
    });

    // MARK: - Connection Close Handler
    ws.on('close', () => {
        console.log('Connection closed');
        if (client) {
            // If client was in audio call, notify the other party
            if (client.audioActive) {
                const targetRole = client.role === 'user' ? 'aid' : 'user';
                broadcastToRole(targetRole, JSON.stringify({
                    type: 'audio_command',
                    command: 'audio_end'
                }));
            }
            clients.delete(ws);      // Remove from clients map
            broadcastStatus();       // Update connection counts
        }
    });

    // MARK: - Error Handler
    ws.on('error', (err) => {
        console.error('WebSocket error:', err);
    });
});

// MARK: - Message Handlers

/**
 * Handles real-time audio data transmission between user and aid
 * Audio flows bidirectionally: user <-> aid
 * @param {Client} sender - Client sending the audio data
 * @param {Buffer} audioData - Raw audio data
 */
function handleAudioData(sender, audioData) {
    if (!sender || !sender.audioActive) return;
    
    // Determine target role (opposite of sender)
    const targetRole = sender.role === 'user' ? 'aid' : 'user';
    
    // Reconstruct audio message with prefix
    const audioMessage = Buffer.concat([
        Buffer.from('AUDIO:'),
        audioData
    ]);
    
    // Send to all clients of target role that have audio active
    let sentCount = 0;
    clients.forEach((client) => {
        if (client.role === targetRole && client.audioActive) {
            client.send(audioMessage);
            sentCount++;
        }
    });
}

/**
 * Handles AR feedback data from user to aid devices
 * This includes processed video with AR annotations/overlays
 * @param {Client} sender - Client sending the feedback
 * @param {Buffer} feedbackData - AR feedback image data
 */
function handleFeedbackData(sender, feedbackData) {
    if (!sender || sender.role !== 'user') return; // Only user can send feedback
    
    // Forward feedback to all aid devices
    let sentCount = 0;
    clients.forEach((client) => {
        if (client.role === 'aid') {
            client.send(feedbackData);
            sentCount++;
        }
    });
}

/**
 * Handles audio call control commands (start/end)
 * Manages audio session state and notifies other participants
 * @param {Client} sender - Client sending the command
 * @param {Object} data - Command data containing 'command' field
 */
function handleAudioCommand(sender, data) {
    if (!sender) return;
    
    switch (data.command) {
        case 'audio_start':
            sender.audioActive = true;
            const targetRole = sender.role === 'user' ? 'aid' : 'user';
            
            // Notify target role about incoming audio call
            broadcastToRole(targetRole, JSON.stringify({
                type: 'audio_command',
                command: 'audio_start'
            }));
            
            console.log(`Audio started by ${sender.role}`);
            break;
            
        case 'audio_end':
            sender.audioActive = false;
            const endTargetRole = sender.role === 'user' ? 'aid' : 'user';
            
            // Notify target role that audio call ended
            broadcastToRole(endTargetRole, JSON.stringify({
                type: 'audio_command',
                command: 'audio_end'
            }));
            
            console.log(`Audio ended by ${sender.role}`);
            break;
    }
}

/**
 * Handles camera image data from user to aid devices
 * This is the primary video stream from user's camera
 * @param {Client} sender - Client sending the image
 * @param {Buffer} imageData - Raw image data (JPEG/PNG)
 */
function handleImageData(sender, imageData) {
    if (!sender || sender.role !== 'user') return; // Only user devices send camera data
    
    // Forward image to all connected aid devices
    let sentCount = 0;
    clients.forEach((client) => {
        if (client.role === 'aid') {
            client.send(imageData);
            sentCount++;
        }
    });
}

/**
 * Handles drawing/annotation messages from aid to user
 * These include drawing strokes and commands for AR rendering
 * @param {Client} sender - Client sending the drawing message
 * @param {Object} data - Drawing message data
 */
function handleDrawingMessage(sender, data) {
    if (!sender || sender.role !== 'aid') return; // Only aid devices can send drawings
    
    // Forward drawing data to user devices for AR processing
    broadcastToRole('user', JSON.stringify(data));
}

// MARK: - Utility Functions

/**
 * Detects if binary data is image data by checking file headers
 * Supports JPEG and PNG formats
 * @param {Buffer} data - Binary data to check
 * @returns {boolean} True if data appears to be an image
 */
function isImageData(data) {
    if (data.length < 4) return false;
    
    // Check for JPEG header (0xFF 0xD8)
    const jpegHeader = data[0] === 0xFF && data[1] === 0xD8;
    // Check for PNG header (0x89 0x50 0x4E 0x47)
    const pngHeader = data[0] === 0x89 && data[1] === 0x50 && data[2] === 0x4E && data[3] === 0x47;
    
    return jpegHeader || pngHeader;
}

/**
 * Broadcasts data to all clients with a specific role
 * @param {string} role - Target role ('user' or 'aid')
 * @param {string|Buffer} data - Data to broadcast
 */
function broadcastToRole(role, data) {
    let sentCount = 0;
    clients.forEach((client) => {
        if (client.role === role) {
            client.send(data);
            sentCount++;
        }
    });
}

/**
 * Broadcasts current connection status to all clients
 * Includes count of connected users and aid devices
 */
function broadcastStatus() {
    const status = {
        type: 'status',
        connectedUsers: Array.from(clients.values()).filter(c => c.role === 'user').length,
        connectedAids: Array.from(clients.values()).filter(c => c.role === 'aid').length
    };
    
    // Send status to all connected clients
    clients.forEach((client) => {
        client.sendJSON(status);
    });
}

// MARK: - Heartbeat/Ping-Pong Mechanism

/**
 * Heartbeat interval to detect and remove dead connections
 * Runs every 30 seconds to check client connectivity
 */
const interval = setInterval(() => {
    wss.clients.forEach((ws) => {
        if (ws.isAlive === false) {
            console.log('Terminating inactive connection');
            return ws.terminate(); // Close dead connection
        }
        
        // Mark as potentially dead and send ping
        // Client must respond with pong to stay alive
        ws.isAlive = false;
        ws.ping();
    });
}, 30000); // 30 second interval

// Clean up heartbeat interval when server closes
wss.on('close', () => {
    clearInterval(interval);
});

// MARK: - Server Startup

const PORT = process.env.PORT || 3000;
server.listen(PORT, '0.0.0.0', () => {
    console.log(`WebSocket server running on port ${PORT}`);
});

