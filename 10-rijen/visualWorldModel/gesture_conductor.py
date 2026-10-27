"""
gesture_conductor.py - Zero-Latency Optical Gesture Conductor for SuperCollider
Engineered for real-time responsiveness on t520:
1. Zero-Latency Camera Thread: Uses native OpenCV V4L2 with a dedicated daemon thread to eliminate all OS pipe buffering.
2. Temporal Motion Differencing: Strips static background (walls, furniture, face) so ONLY moving hands are tracked.
3. Conducting Ictus Detector: Detects momentum reversals (downward strike rebounding upward) and kinetic snaps.
4. Continuous Morphing: Mapped directly to hand elevation, lateral span, and gesture speed.
5. Sends binary OSC directly to SuperCollider (port 57120).
"""

import sys
import os
import time
import socket
import struct
import threading
import argparse
import numpy as np
import pygame
import cv2

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

class ZeroLagCameraGrabber:
    """Native V4L2 camera grabber with background thread to prevent buffer buildup."""
    def __init__(self, device_id=0, width=160, height=120):
        self.w = width
        self.h = height
        self.cap = cv2.VideoCapture(device_id, cv2.CAP_V4L2)
        self.cap.set(cv2.CAP_PROP_FRAME_WIDTH, width)
        self.cap.set(cv2.CAP_PROP_FRAME_HEIGHT, height)
        self.cap.set(cv2.CAP_PROP_BUFFERSIZE, 1)
        self.cap.set(cv2.CAP_PROP_FPS, 30)

        self.latest_frame = np.zeros((height, width), dtype=np.float32)
        self.running = True
        self.lock = threading.Lock()
        
        self.thread = threading.Thread(target=self._worker, daemon=True)
        self.thread.start()
        print(f"[Camera] Direct V4L2 capture active on /dev/video{device_id} ({width}x{height})")

    def _worker(self):
        while self.running:
            ret, frame = self.cap.read()
            if ret:
                gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
                # Flip horizontally so it acts like a mirror
                gray = cv2.flip(gray, 1)
                norm = gray.astype(np.float32) / 255.0
                with self.lock:
                    self.latest_frame = norm
            else:
                time.sleep(0.01)

    def get_frame(self):
        with self.lock:
            return self.latest_frame.copy()

    def close(self):
        self.running = False
        if self.cap.isOpened():
            self.cap.release()

class MotionConductorEngine:
    """Temporal frame-differencing gesture tracker and orchestral ictus detector."""
    def __init__(self, threshold=0.08, ema_alpha=0.65):
        self.thresh = threshold
        self.alpha = ema_alpha
        self.prev_frame = None
        
        # Smoothed motion state
        self.cx = 0.5
        self.cy = 0.5
        self.prev_cx = 0.5
        self.prev_cy = 0.5
        self.vx = 0.0
        self.vy = 0.0
        self.prev_vy = 0.0
        self.energy = 0.0
        self.prev_energy = 0.0
        
        self.ictus_cooldown = 0

    def process(self, frame):
        """
        Takes current grayscale frame in [0, 1].
        Returns: (motion_mask, cx, cy, energy, is_ictus, ictus_intensity)
        """
        if self.prev_frame is None:
            self.prev_frame = frame.copy()
            return np.zeros_like(frame), 0.5, 0.5, 0.0, False, 0.0

        # 1. Temporal Frame Difference (Strips all static background)
        diff = np.abs(frame - self.prev_frame)
        self.prev_frame = frame.copy()

        motion_mask = np.where(diff > self.thresh, diff, 0.0).astype(np.float32)
        total_motion = float(np.sum(motion_mask))

        h, w = frame.shape
        is_ictus = False
        ictus_intensity = 0.0

        if total_motion > 5.0:
            # Centroid of movement (where the hand is)
            y_coords, x_coords = np.mgrid[:h, :w]
            raw_cx = float(np.sum(x_coords * motion_mask) / total_motion) / w
            raw_cy = float(np.sum(y_coords * motion_mask) / total_motion) / h
            
            # Exponential Moving Average for smooth, fluid tracking
            self.cx = self.alpha * raw_cx + (1.0 - self.alpha) * self.cx
            self.cy = self.alpha * raw_cy + (1.0 - self.alpha) * self.cy
            
            # Velocities
            self.vx = self.cx - self.prev_cx
            self.vy = self.cy - self.prev_cy
            
            # Kinetic Energy
            raw_energy = float(np.sqrt(self.vx*self.vx + self.vy*self.vy) * 20.0 + total_motion / 150.0)
            self.energy = 0.5 * raw_energy + 0.5 * self.energy
            
            # 2. THE CONDUCTING ICTUS DETECTOR:
            # In conducting, the beat is the instant the hand reaches the bottom of a stroke
            # and snaps upward (vy flips from positive/downward to negative/upward with high deceleration)
            # OR a sudden spike and sharp arrest in kinetic energy
            jerk = abs(self.vy - self.prev_vy) * 40.0
            energy_snap = (self.prev_energy - self.energy) * 5.0

            if self.ictus_cooldown <= 0:
                # Downward-to-upward rebound OR sharp directional deceleration
                if (self.prev_vy > 0.02 and self.vy <= 0.005) or (jerk > 0.85) or (energy_snap > 1.2 and self.prev_energy > 0.8):
                    is_ictus = True
                    ictus_intensity = float(np.clip(max(jerk, energy_snap, self.energy * 1.5), 0.2, 2.5))
                    self.ictus_cooldown = 6  # Minimum 6 frames (~200ms) between strikes to prevent double-triggering

            self.prev_cx = self.cx
            self.prev_cy = self.cy
            self.prev_vy = self.vy
            self.prev_energy = self.energy
        else:
            # Stillness (Fermata)
            self.energy *= 0.85
            self.vx *= 0.7
            self.vy *= 0.7

        if self.ictus_cooldown > 0:
            self.ictus_cooldown -= 1

        return motion_mask, self.cx, self.cy, self.energy, is_ictus, ictus_intensity

def main():
    parser = argparse.ArgumentParser(description="Zero-Latency SuperCollider Gesture Conductor")
    parser.add_argument("--sc-host", type=str, default="127.0.0.1", help="SuperCollider IP host")
    parser.add_argument("--sc-port", type=int, default=57120, help="SuperCollider UDP port")
    parser.add_argument("--device", type=int, default=0, help="V4L2 Camera ID (default 0)")
    parser.add_argument("--thresh", type=float, default=0.07, help="Motion detection threshold")
    args = parser.parse_args()

    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    sc_dest = (args.sc_host, args.sc_port)
    print(f"[Conductor] Dispatching OSC to SuperCollider at {sc_dest}")

    camera = ZeroLagCameraGrabber(device_id=args.device, width=160, height=120)
    engine = MotionConductorEngine(threshold=args.thresh, ema_alpha=0.7)

    pygame.init()
    pygame.font.init()
    width, height = 1080, 640
    screen = pygame.display.set_mode((width, height))
    pygame.display.set_caption("PixelSense :: Zero-Latency Gesture Conductor (kof)")
    clock = pygame.time.Clock()

    font = pygame.font.SysFont("monospace", 13)
    font_bold = pygame.font.SysFont("monospace", 15, bold=True)
    font_large = pygame.font.SysFont("monospace", 18, bold=True)

    orbit_trail = []
    energy_history = []
    ictus_flash = 0.0
    running = True

    while running:
        for event in pygame.event.get():
            if event.type == pygame.QUIT or (event.type == pygame.KEYDOWN and event.key in [pygame.K_ESCAPE, pygame.K_q]):
                running = False

        # Grab zero-lag frame
        frame = camera.get_frame()
        motion_mask, cx, cy, energy, is_ictus, ictus_intensity = engine.process(frame)

        # 1. Trigger Ictus Strike
        if is_ictus:
            ictus_flash = 1.0
            lateral_axis = float(cx)  # 0.0 (left) to 1.0 (right)
            pkt_ictus = make_osc_msg("/conductor/ictus", float(ictus_intensity), float(lateral_axis))
            sock.sendto(pkt_ictus, sc_dest)

        # 2. Continuous Conductor Flow:
        # z0 = Elevation (inverted: hand high = high filter cutoff)
        # z1 = Lateral (pan: -1.0 left, +1.0 right)
        # z2 = Energy (harmonic richness)
        # z3 = Depth/Speed
        z0 = float((1.0 - cy - 0.5) * 4.0)
        z1 = float((cx - 0.5) * 4.0)
        z2 = float(np.clip(energy, 0.0, 3.0))
        z3 = float(np.clip(abs(engine.vy) * 20.0, 0.0, 3.0))

        pkt_morph = make_osc_msg("/conductor/morph", z0, z1, z2, z3)
        sock.sendto(pkt_morph, sc_dest)

        # 3. Tension / Kinetic Energy
        pkt_tension = make_osc_msg("/conductor/tension", float(energy), float(ictus_flash * 2.0))
        sock.sendto(pkt_tension, sc_dest)

        ictus_flash *= 0.80
        orbit_trail.append((float(cx), float(cy)))
        if len(orbit_trail) > 90:
            orbit_trail.pop(0)

        energy_history.append(energy)
        if len(energy_history) > 120:
            energy_history.pop(0)

        # --- DRAWING PIPELINE ---
        screen.fill((8, 10, 14))

        p_w, p_h = 300, 225
        p1_x, p1_y = 40, 50
        p2_x = 380
        p3_x = 720

        # Viewport 1: Camera Mirror
        rgb_cam = np.repeat((frame * 255).astype(np.uint8)[:, :, np.newaxis], 3, axis=2)
        surf_cam = pygame.transform.scale(pygame.surfarray.make_surface(rgb_cam.swapaxes(0, 1)), (p_w, p_h))
        screen.blit(surf_cam, (p1_x, p1_y))
        pygame.draw.rect(screen, (35, 45, 55), (p1_x - 1, p1_y - 1, p_w + 2, p_h + 2), 1)
        screen.blit(font_bold.render("1. OPTICAL MIRROR (ZERO-LAG)", True, (200, 220, 240)), (p1_x, p1_y - 24))

        # Viewport 2: Motion Energy Silhouette (Static Background Stripped)
        rgb_mot = np.zeros((motion_mask.shape[0], motion_mask.shape[1], 3), dtype=np.uint8)
        rgb_mot[:, :, 0] = (motion_mask * 40).clip(0, 255).astype(np.uint8)
        rgb_mot[:, :, 1] = (motion_mask * 230).clip(0, 255).astype(np.uint8)
        rgb_mot[:, :, 2] = (motion_mask * 255).clip(0, 255).astype(np.uint8)
        surf_mot = pygame.transform.scale(pygame.surfarray.make_surface(rgb_mot.swapaxes(0, 1)), (p_w, p_h))
        screen.blit(surf_mot, (p2_x, p1_y))
        pygame.draw.rect(screen, (25, 60, 75), (p2_x - 1, p1_y - 1, p_w + 2, p_h + 2), 1)
        screen.blit(font_bold.render("2. MOTION SILHOUETTE (BACKGROUND STRIPPED)", True, (60, 210, 255)), (p2_x, p1_y - 24))

        # Viewport 3: The Ictus Strike Reticle
        pygame.draw.rect(screen, (14, 18, 24), (p3_x, p1_y, p_w, p_h))
        pygame.draw.rect(screen, (80, 50, 20), (p3_x, p1_y, p_w, p_h), 1)
        screen.blit(font_bold.render("3. THE ICTUS (SONIC MOMENT)", True, (255, 180, 50)), (p3_x, p1_y - 24))

        mid_x = p3_x + p_w // 2
        mid_y = p1_y + p_h // 2
        reticle_r = int(24 + ictus_flash * 65)
        col_ret = (int(255 * ictus_flash), int(180 + 75 * ictus_flash), int(40 * (1 - ictus_flash)))
        pygame.draw.circle(screen, col_ret, (mid_x, mid_y), reticle_r, 2)
        if ictus_flash > 0.08:
            pygame.draw.circle(screen, (255, 230, 100), (mid_x, mid_y), int(18 * ictus_flash))
            screen.blit(font_bold.render(">>> STRIKE! <<<", True, (255, 220, 80)), (mid_x - 55, mid_y + 40))

        # Bottom Left: Conducting Orbit Scope
        o_x, o_y, o_w, o_h = 40, 320, 480, 270
        pygame.draw.rect(screen, (12, 16, 22), (o_x, o_y, o_w, o_h))
        pygame.draw.rect(screen, (25, 45, 65), (o_x, o_y, o_w, o_h), 1)
        screen.blit(font_large.render("CONDUCTING ORBIT & TRAJECTORY", True, (180, 200, 220)), (o_x + 16, o_y + 14))

        # Grid lines
        pygame.draw.line(screen, (22, 30, 40), (o_x + o_w//2, o_y + 35), (o_x + o_w//2, o_y + o_h - 15), 1)
        pygame.draw.line(screen, (22, 30, 40), (o_x + 20, o_y + o_h//2 + 10), (o_x + o_w - 20, o_y + o_h//2 + 10), 1)

        # Draw trajectory trail
        if len(orbit_trail) > 1:
            for k in range(1, len(orbit_trail)):
                x1 = int(o_x + 20 + orbit_trail[k-1][0] * (o_w - 40))
                y1 = int(o_y + 35 + orbit_trail[k-1][1] * (o_h - 50))
                x2 = int(o_x + 20 + orbit_trail[k][0] * (o_w - 40))
                y2 = int(o_y + 35 + orbit_trail[k][1] * (o_h - 50))
                alpha = int((k / len(orbit_trail)) * 240)
                pygame.draw.line(screen, (40, alpha, 255), (x1, y1), (x2, y2), 2)
                
            # Current hand position
            cur_x = int(o_x + 20 + cx * (o_w - 40))
            cur_y = int(o_y + 35 + cy * (o_h - 50))
            pygame.draw.circle(screen, (255, 230, 100), (cur_x, cur_y), 6)

        # Bottom Right: Kinetic Energy & Strike Waveform
        k_x, k_y, k_w, k_h = 540, 320, 500, 270
        pygame.draw.rect(screen, (12, 16, 22), (k_x, k_y, k_w, k_h))
        pygame.draw.rect(screen, (25, 45, 65), (k_x, k_y, k_w, k_h), 1)
        screen.blit(font_large.render("KINETIC ENERGY SPECTRUM (GESTURE SPEED)", True, (180, 200, 220)), (k_x + 16, k_y + 14))

        base_y = k_y + k_h - 35
        pygame.draw.line(screen, (30, 40, 50), (k_x + 20, base_y), (k_x + k_w - 20, base_y), 1)

        if len(energy_history) > 1:
            step_w = (k_w - 40) / max(len(energy_history), 1)
            for k in range(1, len(energy_history)):
                x1 = k_x + 20 + int((k - 1) * step_w)
                y1 = base_y - int(np.clip(energy_history[k - 1] * 65, 0, k_h - 70))
                x2 = k_x + 20 + int(k * step_w)
                y2 = base_y - int(np.clip(energy_history[k] * 65, 0, k_h - 70))
                col = (255, 180, 50) if energy_history[k] > 1.2 else (60, 210, 240)
                pygame.draw.line(screen, col, (x1, y1), (x2, y2), 2)

        # Live stats overlay
        screen.blit(font.render(f"Hand Pos: ({cx:.2f}, {cy:.2f})  Energy: {energy:.2f}", True, (160, 180, 200)), (o_x + 20, o_y + o_h - 25))
        screen.blit(font.render(f"OSC Target: {sc_dest[0]}:{sc_dest[1]}  [Q] to quit", True, (130, 150, 170)), (k_x + 20, k_y + k_h - 25))

        pygame.display.flip()
        clock.tick(30)

    camera.close()
    sock.close()
    pygame.quit()

if __name__ == "__main__":
    main()
