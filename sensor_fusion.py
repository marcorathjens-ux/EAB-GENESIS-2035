import numpy as np
import zmq

class EAB_SensorFusion:
    def __init__(self):
        self.sr, self.alpha_eff, self.b_julia = 44100, 0.4, 1.0
        self._ipc_counter = 0 
        self.socket = zmq.Context().socket(zmq.PUSH)
        self.socket.connect("tcp://localhost:5555")

    def calculate_trigger_threshold(self, noise_level):
        D = (noise_level**2) / 2
        if D < 1e-9: return 1.0
        
        # CORRECTED KRAMERS (R3-03 Fix)
        delta_V = (self.alpha_eff**2) / (4 * self.b_julia)
        omega_a, omega_b = np.sqrt(2 * self.alpha_eff), np.sqrt(self.alpha_eff)
        prefactor = (omega_a * omega_b) / (2 * np.pi)
        kramers_rate = prefactor * np.exp(-delta_V / D)
        
        sr_gain = np.clip(kramers_rate / (kramers_rate + 120.0), 0, 0.4)
        
        # DECIMATION (R3-02 Fix)
        self._ipc_counter += 1
        if self._ipc_counter >= 441: # 10ms sync
            self.socket.send_json({"sigma": float(noise_level), "gain": float(sr_gain)})
            self._ipc_counter = 0
        return max(0.2, 1.0 * (1 - sr_gain))
