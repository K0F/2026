"""
gesture_conductor.py - Vision-to-Sound Gesture Conducting Engine
Extracts sonically significant moments from optical gestures:
1. Ictus Detection: Instantaneous jerk (d^3 z / dt^3) triggers resonant modal strikes
2. Continuous Flow: Latent space manifold (z0..z3) modulates wavetable synthesis & filters
3. Epistemic Surprise: Prediction errors trigger harmonic FM dissonance
4. Sends pure binary OSC over UDP to SuperCollider (port 57120).
Runs on both bazina (PyTorch deep encoder) and t520 (NumPy harmonic encoder).
"""

import sys
import os
import time
import socket
import struct
import subprocess
import argparse
import numpy as np
import pygame

# Optional PyTorch import
HAS_TORCH = False
try:
    import torch
    from spatial_autoencoder import SpatialAutoencoder
    from latent_dynamics import LatentWorldModel
    HAS_TORCH = True
except ImportError:
    HAS_TORCH = False

def make_osc_msg(address, *args):
    """Zero-dependency pure binary OSC encoder."""
    b_addr = address.encode('utf-8') + b'\0'
    while len(b_addr) % 4 != 0: b_addr += b'\0'
    
    tags = ','
    payload = b''
    for a in args:
        if isinstance(a, float) or isinstance(a, np.floating):
            tags += 'f'
            payload += struct.pack('>f', float(a))
        elif isinstance(a, int) or isinstance(a, np.integer):
            tags += 'i'
            payload += struct.pack('>i', int(a))
        elif isinstance(a, str):
            tags += 's'
            b_s = a.encode('utf-8') + b'\0'
            while len(b_s) % 4 != 0: b_s += b'\0'
            payload += b_s
            
    b_tags = tags.encode('utf-8') + b'\0'
    while len(b_tags) % 4 != 0: b_tags += b'\0'
    return b_addr + b_tags + payload

class VideoStreamGrabber:
    """
    Grabs 64x64 frames from:
    1. Local /dev/video0 (on t520 via ffmpeg pipe)
    2. UDP port 5555 (on bazina, receiving live camera from t520)
    3. Synthetic conducting gesture fallback (Lissajous conducting beats)
    """
    def __init__(self, device_path="/dev/video0", width=64, height=64, udp_port=5555):
        self.w = width
        self.h = height
        self.frame_bytes = width * height
        self.proc = None
        self.udp_sock = None
        self.synthetic_phase = 0.0
        self.source_mode = "synthetic"
        
        # 1. Try Local V4L2 device
        if device_path.startswith("/dev/video") and os.path.exists(device_path):
            try:
                cmd = [
                    "ffmpeg", "-f", "v4l2", "-video_size", "320x240", "-framerate", "30",
                    "-i", device_path,
                    "-vf", f"scale={width}:{height},format=gray",
                    "-f", "rawvideo", "-"
                ]
                self.proc = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
                self.source_mode = "local_v4l2"
                print(f"[VideoStream] Connected to local webcam {device_path} via ffmpeg pipe.")
            except Exception as e:
                print(f"[VideoStream] Error opening {device_path}: {e}")
                self.proc = None

        # 2. If local device not found or UDP explicitly requested, listen on UDP port
        if self.proc is None or device_path.startswith("udp"):
            try:
                import select
                self.select = select
                self.udp_sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
                self.udp_sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
                self.udp_sock.bind(("0.0.0.0", udp_port))
                self.udp_sock.setblocking(False)
                self.source_mode = "network_udp"
                print(f"[VideoStream] Local camera not present. Listening on UDP port {udp_port} for fleet camera stream (from t520)...")
            except Exception as e:
                print(f"[VideoStream] UDP socket bind failed: {e}")
                self.udp_sock = None

    def read_frame(self):
        # Local ffmpeg pipe
        if self.proc is not None:
            raw = self.proc.stdout.read(self.frame_bytes)
            if len(raw) == self.frame_bytes:
                arr = np.frombuffer(raw, dtype=np.uint8).reshape((self.h, self.w))
                return arr.astype(np.float32) / 255.0

        # Network UDP receiver (freshest frame)
        if self.udp_sock is not None:
            got_pkt = False
            last_raw = None
            while True:
                ready = self.select.select([self.udp_sock], [], [], 0.0)
                if not ready[0]:
                    break
                try:
                    data, _ = self.udp_sock.recvfrom(65535)
                    if len(data) >= self.frame_bytes:
                        last_raw = data[:self.frame_bytes]
                        got_pkt = True
                except Exception:
                    break
            if got_pkt and last_raw is not None:
                arr = np.frombuffer(last_raw, dtype=np.uint8).reshape((self.h, self.w))
                return arr.astype(np.float32) / 255.0

        # Synthetic Conducting Gesture Fallback (Lissajous trajectory with conducting beats)
        self.synthetic_phase += 0.08
        t = self.synthetic_phase
        cy = 32.0 + np.abs(np.sin(t * 1.5)) * 22.0 - 10.0
        cx = 32.0 + np.sin(t * 0.75) * 18.0
        
        y_grid, x_grid = np.ogrid[:self.h, :self.w]
        d2 = (x_grid - cx)**2 + (y_grid - cy)**2
        flame = np.exp(-d2 / 24.0) * 0.95
        noise = np.random.normal(0.0, 0.02, (self.h, self.w))
        return np.clip(flame + noise, 0.0, 1.0).astype(np.float32)

    def close(self):
        if self.proc is not None:
            self.proc.terminate()
        if self.udp_sock is not None:
            self.udp_sock.close()

class NumpySpatialEncoder:
    """Zero-dependency spatial moment and harmonic DCT encoder (pure NumPy)"""
    def __init__(self, latent_dim=16):
        self.dim = latent_dim

    def encode(self, frame):
        h, w = frame.shape
        y_coords, x_coords = np.mgrid[:h, :w]
        total_mass = np.sum(frame) + 1e-6
        
        # Spatial Centroids (z0: Y-altitude, z1: X-lateral)
        cy = np.sum(y_coords * frame) / total_mass
        cx = np.sum(x_coords * frame) / total_mass
        
        # Normalized to [-2.0, 2.0]
        z0 = float((cy / h - 0.5) * 4.0)
        z1 = float((cx / w - 0.5) * 4.0)
        
        # Spatial Spread (z2: dispersion / density)
        spread = np.sqrt(np.sum(((y_coords - cy)**2 + (x_coords - cx)**2) * frame) / total_mass)
        z2 = float((spread / (h * 0.5) - 0.5) * 4.0)
        
        # Mass / Proximity (z3)
        z3 = float((total_mass / (h * w) - 0.15) * 6.0)

        # 4x4 Grid Block Moments (z4..z15)
        blocks = []
        bh, bw = h // 4, w // 4
        for r in range(4):
            for c in range(4):
                if len(blocks) < self.dim - 4:
                    block_mean = np.mean(frame[r*bh:(r+1)*bh, c*bw:(c+1)*bw])
                    blocks.append(float((block_mean - 0.2) * 5.0))

        z_vec = np.array([z0, z1, z2, z3] + blocks, dtype=np.float32)
        return z_vec[:self.dim]

def main():
    parser = argparse.ArgumentParser(description="Gesture Conductor: Vision to SuperCollider")
    parser.add_argument("--sc-host", type=str, default="127.0.0.1", help="SuperCollider IP host")
    parser.add_argument("--sc-port", type=int, default=57120, help="SuperCollider UDP port")
    parser.add_argument("--device", type=str, default="/dev/video0", help="Video device path")
    parser.add_argument("--threshold", type=float, default=0.60, help="Ictus strike sensitivity threshold")
    args = parser.parse_args()

    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    sc_dest = (args.sc_host, args.sc_port)
    print(f"[Conductor] Dispatching OSC to SuperCollider at {sc_dest}")

    camera = VideoStreamGrabber(device_path=args.device, width=64, height=64)

    # Choose Encoder
    if HAS_TORCH:
        device = "cuda" if torch.cuda.is_available() else "cpu"
        vision_net = SpatialAutoencoder(latent_dim=16).to(device)
        world_net = LatentWorldModel(latent_dim=16, action_dim=3, hidden_dim=64).to(device)
        print(f"[Conductor] Engine: PyTorch Deep Spatial Autoencoder on {device}")
    else:
        numpy_encoder = NumpySpatialEncoder(latent_dim=16)
        print("[Conductor] Engine: NumPy Spatial Harmonic Moment Encoder (Zero-Bloat)")

    pygame.init()
    pygame.font.init()
    width, height = 1080, 640
    screen = pygame.display.set_mode((width, height))
    pygame.display.set_caption("PixelSense :: SuperCollider Gesture Conductor (kof)")
    clock = pygame.time.Clock()

    font = pygame.font.SysFont("monospace", 13)
    font_bold = pygame.font.SysFont("monospace", 15, bold=True)
    font_large = pygame.font.SysFont("monospace", 18, bold=True)

    z_prev = np.zeros(16, dtype=np.float32)
    v_prev = np.zeros(16, dtype=np.float32)
    a_prev = np.zeros(16, dtype=np.float32)
    jerk_history = []
    orbit_trail = []

    running = True
    ictus_flash = 0.0

    while running:
        for event in pygame.event.get():
            if event.type == pygame.QUIT or (event.type == pygame.KEYDOWN and event.key in [pygame.K_ESCAPE, pygame.K_q]):
                running = False

        frame = camera.read_frame()

        # 1. Encode Latent Vector z
        if HAS_TORCH:
            t_frame = torch.tensor(frame, dtype=torch.float32, device=device).unsqueeze(0).unsqueeze(0)
            with torch.no_grad():
                z_curr = vision_net.encode(t_frame).squeeze().cpu().numpy()
                h_init = world_net.init_hidden(1, device=device)
                a_dummy = torch.tensor([1], dtype=torch.long, device=device)
                z_pred, _, _ = world_net.forward_transition(
                    torch.tensor(z_curr, dtype=torch.float32, device=device).unsqueeze(0),
                    a_dummy, h_init
                )
                z_dream = z_pred.squeeze().cpu().numpy()
                surprise = float(np.linalg.norm(z_curr - z_dream))
        else:
            z_curr = numpy_encoder.encode(frame)
            # Extrapolate linear inertia as simple latent prediction
            z_dream = z_prev + v_prev
            surprise = float(np.linalg.norm(z_curr - z_dream))

        # 2. Compute Derivatives: Velocity, Acceleration, and Jerk
        v_curr = z_curr - z_prev
        a_curr = v_curr - v_prev
        jerk_vec = a_curr - a_prev
        
        energy = float(np.linalg.norm(v_curr))
        jerk_mag = float(np.linalg.norm(jerk_vec))

        # 3. Sonically Significant Moment: The Ictus Strike
        is_ictus = False
        if jerk_mag > args.threshold and (len(jerk_history) > 1 and jerk_mag > jerk_history[-1]):
            is_ictus = True
            ictus_flash = 1.0
            
            intensity = float(np.clip(jerk_mag / 1.5, 0.1, 2.0))
            lateral_axis = float(np.clip((z_curr[1] + 2.0) / 4.0, 0.0, 1.0))
            
            # Send Ictus Strike OSC packet
            pkt_ictus = make_osc_msg("/conductor/ictus", intensity, lateral_axis)
            sock.sendto(pkt_ictus, sc_dest)

        jerk_history.append(jerk_mag)
        if len(jerk_history) > 100:
            jerk_history.pop(0)

        # 4. Continuous Flow OSC (Morphing & Spatial Coordinates)
        pkt_morph = make_osc_msg("/conductor/morph", float(z_curr[0]), float(z_curr[1]), float(z_curr[2]), float(z_curr[3]))
        sock.sendto(pkt_morph, sc_dest)

        # 5. Tension OSC (Kinetic Energy & Epistemic Surprise)
        pkt_tension = make_osc_msg("/conductor/tension", energy, surprise)
        sock.sendto(pkt_tension, sc_dest)

        # Update history
        z_prev = z_curr.copy()
        v_prev = v_curr.copy()
        a_prev = a_curr.copy()
        ictus_flash *= 0.82

        orbit_trail.append((float(z_curr[1]), float(z_curr[0])))
        if len(orbit_trail) > 120:
            orbit_trail.pop(0)

        # --- DRAWING PIPELINE ---
        screen.fill((8, 10, 14))

        # Panel 1: Optical Camera Eye
        p1_x, p1_y, p_sz = 40, 50, 260
        rgb = np.repeat((np.clip(frame, 0.0, 1.0) * 255).astype(np.uint8)[:, :, np.newaxis], 3, axis=2)
        surf_cam = pygame.transform.scale(pygame.surfarray.make_surface(rgb.swapaxes(0, 1)), (p_sz, p_sz))
        screen.blit(surf_cam, (p1_x, p1_y))
        pygame.draw.rect(screen, (35, 45, 55), (p1_x - 1, p1_y - 1, p_sz + 2, p_sz + 2), 1)
        screen.blit(font_bold.render("1. OPTICAL SENSORY INPUT", True, (200, 220, 240)), (p1_x, p1_y - 24))

        # Panel 2: Conducting Orbit
        p2_x = 340
        pygame.draw.rect(screen, (12, 16, 22), (p2_x, p1_y, p_sz, p_sz))
        pygame.draw.rect(screen, (25, 60, 75), (p2_x, p1_y, p_sz, p_sz), 1)
        screen.blit(font_bold.render("2. CONDUCTING ORBIT (z0 x z1)", True, (60, 210, 255)), (p2_x, p1_y - 24))

        mid_x = p2_x + p_sz // 2
        mid_y = p1_y + p_sz // 2
        pygame.draw.line(screen, (25, 35, 45), (mid_x, p1_y), (mid_x, p1_y + p_sz), 1)
        pygame.draw.line(screen, (25, 35, 45), (p2_x, mid_y), (p2_x + p_sz, mid_y), 1)

        if len(orbit_trail) > 1:
            for k in range(1, len(orbit_trail)):
                x1 = mid_x + int(orbit_trail[k-1][0] * 38)
                y1 = mid_y - int(orbit_trail[k-1][1] * 38)
                x2 = mid_x + int(orbit_trail[k][0] * 38)
                y2 = mid_y - int(orbit_trail[k][1] * 38)
                alpha_col = int((k / len(orbit_trail)) * 220)
                pygame.draw.line(screen, (40, alpha_col, 255), (x1, y1), (x2, y2), 1)

        # Panel 3: Ictus Strike
        p3_x = 640
        pygame.draw.rect(screen, (12, 16, 22), (p3_x, p1_y, p_sz, p_sz))
        pygame.draw.rect(screen, (80, 50, 20), (p3_x, p1_y, p_sz, p_sz), 1)
        screen.blit(font_bold.render("3. THE ICTUS (MOMENT OF STRIKE)", True, (255, 180, 50)), (p3_x, p1_y - 24))

        reticle_r = int(25 + ictus_flash * 60)
        reticle_col = (int(255 * ictus_flash), int(180 + 75 * ictus_flash), int(40 * (1 - ictus_flash)))
        pygame.draw.circle(screen, reticle_col, (p3_x + p_sz // 2, p1_y + p_sz // 2), reticle_r, 2)
        if ictus_flash > 0.1:
            pygame.draw.circle(screen, (255, 230, 100), (p3_x + p_sz // 2, p1_y + p_sz // 2), int(15 * ictus_flash))

        # Bottom Panel: Jerk Waveform
        b_x, b_y, b_w, b_h = 40, 350, 860, 240
        pygame.draw.rect(screen, (14, 18, 24), (b_x, b_y, b_w, b_h))
        pygame.draw.rect(screen, (30, 40, 50), (b_x, b_y, b_w, b_h), 1)
        screen.blit(font_large.render("GESTURE INFLECTION SPECTRUM [JERK ACCELERATION & SURPRISE]", True, (180, 200, 220)), (b_x + 16, b_y + 14))

        j_base_y = b_y + 190
        pygame.draw.line(screen, (40, 50, 65), (b_x + 20, j_base_y), (b_x + b_w - 20, j_base_y), 1)
        
        thresh_y = j_base_y - int(args.threshold * 70)
        pygame.draw.line(screen, (200, 80, 50), (b_x + 20, thresh_y), (b_x + b_w - 20, thresh_y), 1)
        screen.blit(font.render(f"ICTUS THRESHOLD ({args.threshold:.2f})", True, (220, 100, 70)), (b_x + b_w - 200, thresh_y - 14))

        if len(jerk_history) > 1:
            step_w = (b_w - 40) / max(len(jerk_history), 1)
            for k in range(1, len(jerk_history)):
                x1 = b_x + 20 + int((k - 1) * step_w)
                y1 = j_base_y - int(np.clip(jerk_history[k - 1] * 70, 0, 150))
                x2 = b_x + 20 + int(k * step_w)
                y2 = j_base_y - int(np.clip(jerk_history[k] * 70, 0, 150))
                col = (255, 200, 60) if jerk_history[k] >= args.threshold else (60, 180, 220)
                pygame.draw.line(screen, col, (x1, y1), (x2, y2), 2)

        # Right Telemetry
        r_x, r_y, r_w, r_h = 920, 50, 140, 540
        pygame.draw.rect(screen, (14, 18, 24), (r_x, r_y, r_w, r_h))
        pygame.draw.rect(screen, (30, 40, 50), (r_x, r_y, r_w, r_h), 1)
        screen.blit(font_bold.render("OSC METRICS", True, (240, 205, 50)), (r_x + 10, r_y + 12))

        sc_lines = [
            f"Port:  {args.sc_port}",
            f"Jerk:  {jerk_mag:.2f}",
            f"Energy:{energy:.2f}",
            f"Surpr: {surprise:.2f}",
            "",
            "ICTUS EVENT:",
            f"{'TRIGGERED' if ictus_flash > 0.4 else '---'}",
            "",
            "CONTROLS:",
            "[Q] Quit",
        ]
        ty = r_y + 40
        for l in sc_lines:
            col = (255, 180, 50) if "TRIGGERED" in l else (180, 200, 220)
            screen.blit(font.render(l, True, col), (r_x + 10, ty))
            ty += 18

        pygame.display.flip()
        clock.tick(30)

    camera.close()
    sock.close()
    pygame.quit()

if __name__ == "__main__":
    main()
