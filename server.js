const express = require('express');
const http = require('http');
const { Server } = require('socket.io');

const app = express();
const server = http.createServer(app);
const io = new Server(server, {
    cors: { origin: "*" } // Mengizinkan koneksi dari Emulator/HP
});

io.on('connection', (socket) => {
    console.log('📱 Perangkat Terhubung! ID Socket:', socket.id);

    // Mendengarkan data lokasi real-time dari Flutter
    socket.on('track_location', (data, ack) => {
        console.log('\n📍 MASUK KOORDINAT BARU:');
        console.log(`- ID Lokal  : ${data.id_lokal}`);
        console.log(`- Latitude  : ${data.latitude}`);
        console.log(`- Longitude : ${data.longitude}`);
        console.log(`- Waktu     : ${data.timestamp}`);

        if (ack) {
            ack({ status: 'success', message: 'Data aman di server pusat' });
        }
    });

    socket.on('disconnect', () => {
        console.log('❌ Perangkat Terputus:', socket.id);
    });
});

server.listen(3000, () => {
    console.log('🚀 Server Socket.IO berjalan di http://localhost:3000');
});