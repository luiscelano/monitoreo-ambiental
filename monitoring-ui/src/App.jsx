import { useState, useCallback } from 'react'
import { Box, Container, Grid, Paper, Typography } from '@mui/material';
import { useRef } from 'react';
import { useEffect } from 'react';

const WEBSOCKET_URL = "wss://108dpxfuq2.execute-api.us-east-1.amazonaws.com/$default";

function App() {
  const ref = useRef(false);
  const [monitoringData, setMonitoringData] = useState({
      temperature: "0",
      humidity: "0",
      air_quality: "0"
  })

  const startConnection = useCallback(()=> {
    const socket = new WebSocket(WEBSOCKET_URL);

    socket.onopen = () => {
    console.log("✅ Connected to WebSocket");
    
    };

    socket.onmessage = (event) => {
        console.log("📩 Message from server:", JSON.parse(event.data));
        setMonitoringData({...JSON.parse(event.data)})
    };

    socket.onerror = (error) => {
        console.error("❌ WebSocket Error:", error);
    };

    socket.onclose = () => {
        console.log("🔌 Connection closed");
    };
  },[]);

  useEffect(()=> {
    if(ref.current) return;
    ref.current = true;
    startConnection();
  },[])

  return (
    <>
      <Box sx={{flexGrow: 1, marginTop: '5%'}}>
        <Container maxWidth="lg">
        <Grid container spacing={5}>
          <Grid size={12} sx={{textAlign: 'center'}}>
              <Typography variant='h2'>Monitoreo Ambiental</Typography>
          </Grid>
          <Grid size={{xs: 12, md: 4, sm: 6}}>
            <Paper sx={{ textAlign: 'center'}}>
              <Typography variant='h5'>Temperatura</Typography>
              <Typography variant='h3'>{monitoringData.temperature}</Typography>
            </Paper>
          </Grid>
          <Grid size={{xs: 12, md: 4, sm: 6}}>
            <Paper sx={{ textAlign: 'center'}}>
              <Typography variant='h5'>Humedad</Typography>
              <Typography variant='h3'>{monitoringData.humidity}</Typography>
            </Paper>
          </Grid>
          <Grid size={{xs: 12, md: 4, sm: 6}}>
            <Paper sx={{ textAlign: 'center'}}>
              <Typography variant='h5'>Calidad de aire</Typography>
              <Typography variant='h3'>{monitoringData.air_quality}</Typography>
            </Paper>
          </Grid>
        </Grid>
      </Container>
      </Box>
    </>
  )
}

export default App
