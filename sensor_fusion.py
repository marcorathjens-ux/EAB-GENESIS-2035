import numpy as np
import zmq
import json

class EAB_SensorFusion:
    def __init__(self, sampling_rate=44100):
        self.sr = sampling_rate
        self.alpha_eff = 0.4
        self.b_coeff = 0.1
        self.f_signal = 120.0 # Target frequency
        
        # Setup ZMQ IPC Bridge to Julia
        self.context = zmq.Context()
        self.socket = self.context.socket(zmq.PUSH)
        self.socket.connect("tcp://localhost:5555")

    def adaptive_filter(self, raw_signal):
        """IMPLEMENTED: Real FFT-Bandpass with Hann-Windowing."""
        n = len(raw_signal)
        window = np.hanning(n)
        fft_signal = np.fft.fft(raw_signal * window)
        freqs = np.fft.fftfreq(n, d=1.0/self.sr)
        
        # Real Bandpass Mask: 50–200 Hz
        mask = (np.abs(freqs) >= 50) & (np.abs(freqs) <= 200)
        fft_signal[~mask] = 0
        return np.real(np.fft.ifft(fft_signal))

    def calculate_trigger_threshold(self, noise_level):
        """IMPLEMENTED: Non-linear SR-Gain via Kramers-Rate."""
        D = (noise_level**2) / 2
        if D < 1e-9: return 1.0
        delta_V = (self.alpha_eff**2) / (4 * self.b_coeff)
        kramers_rate = np.exp(-delta_V / D)
        sr_gain = np.clip(kramers_rate / (kramers_rate + self.f_signal), 0, 0.4)
        
        # Send dynamic Sigma to Julia via IPC
        self.socket.send_json({"sigma": noise_level, "gain": float(sr_gain)})
        return max(0.2, 1.0 * (1 - sr_gain))

sf = EAB_SensorFusion()
print("Sensor Fusion V2.2: Real-time IPC & SR-Optimum active.")
