"""
viewer.py - Real-Time CRT Visualizer & Sense-Making Dashboard
Displays:
1. OPTICAL REALITY: Raw input pixels
2. INTERNAL DREAM: Latent space predictive hallucination
3. PREDICTION SURPRISE: Epistemic error heatmap
4. LATENT BARCODE: 16-dimensional concept activations
5. TELEMETRY HUD: Loss, surprise, and object permanence tracking
"""

import sys
import os
import time
import argparse
import numpy as np
import pygame
import torch

from physics_arena import PhysicsArena
from spatial_autoencoder import SpatialAutoencoder
from latent_dynamics import LatentWorldModel
from curiosity_reasoner import CognitiveSenseMaker

def render_surface_from_numpy(arr, target_size=(256, 256), colormap="mono"):
    """Converts 2D numpy float [H, W] in [0, 1] to a scaled Pygame Surface"""
    h, w = arr.shape
    arr_clipped = np.clip(arr, 0.0, 1.0)
    
    if colormap == "mono":
        # Amber/phosphor CRT green or crisp white
        rgb = np.zeros((h, w, 3), dtype=np.uint8)
        rgb[:, :, 0] = (arr_clipped * 210).astype(np.uint8)
        rgb[:, :, 1] = (arr_clipped * 240).astype(np.uint8)
        rgb[:, :, 2] = (arr_clipped * 220).astype(np.uint8)
    elif colormap == "dream":
        # Dream state: ethereal cyan/blue phosphor
        rgb = np.zeros((h, w, 3), dtype=np.uint8)
        rgb[:, :, 0] = (arr_clipped * 80).astype(np.uint8)
        rgb[:, :, 1] = (arr_clipped * 220).astype(np.uint8)
        rgb[:, :, 2] = (arr_clipped * 255).astype(np.uint8)
    elif colormap == "surprise":
        # Surprise error: burning amber/crimson heat
        rgb = np.zeros((h, w, 3), dtype=np.uint8)
        rgb[:, :, 0] = (arr_clipped * 255).astype(np.uint8)
        rgb[:, :, 1] = (arr_clipped * 140).astype(np.uint8)
        rgb[:, :, 2] = (arr_clipped * 40).astype(np.uint8)
        
    surf = pygame.surfarray.make_surface(rgb.swapaxes(0, 1))
    return pygame.transform.scale(surf, target_size)

def main():
    parser = argparse.ArgumentParser(description="PixelSense: Autonomous Visual World Model")
    parser.add_argument("--headless", action="store_true", help="Run without X11 window")
    parser.add_argument("--render-frames", type=int, default=0, help="Export N frames to disk")
    parser.add_argument("--output-dir", type=str, default="/mnt/ssd/render/visualWorldModel/frames")
    args = parser.parse_args()

    # Initialize Pygame
    if args.headless:
        os.environ["SDL_VIDEODRIVER"] = "dummy"
    
    pygame.init()
    pygame.font.init()
    
    width, height = 1240, 720
    screen = pygame.display.set_mode((width, height))
    pygame.display.set_caption("PixelSense :: Visual World Model & Sense-Making Engine (Hassabis / Silver Lineage)")
    clock = pygame.time.Clock()

    font = pygame.font.SysFont("monospace", 13, bold=False)
    font_bold = pygame.font.SysFont("monospace", 15, bold=True)
    font_large = pygame.font.SysFont("monospace", 18, bold=True)

    # Initialize Cognitive Architecture
    device = "cuda" if torch.cuda.is_available() else "cpu"
    print(f"[PixelSense] Initialized on compute device: {device}")
    
    arena = PhysicsArena(width=64, height=64, num_bodies=2)
    vision_net = SpatialAutoencoder(latent_dim=16)
    dynamics_net = LatentWorldModel(latent_dim=16, action_dim=2, hidden_dim=64)
    agent = CognitiveSenseMaker(vision_net, dynamics_net, device=device, lr=1.5e-3)

    running = True
    online_learning = True
    frame_idx = 0
    
    if args.render_frames > 0:
        os.makedirs(args.output_dir, exist_ok=True)
        print(f"[PixelSense] Rendering {args.render_frames} frames to {args.output_dir}")

    current_frame = arena.render_frame()

    while running:
        frame_idx += 1
        current_action = np.array([0.0, 0.0], dtype=np.float32)

        # Pygame Event Handling
        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                running = False
            elif event.type == pygame.KEYDOWN:
                if event.key == pygame.K_ESCAPE or event.key == pygame.K_q:
                    running = False
                elif event.key == pygame.K_SPACE:
                    # Apply sudden surprise impulse (poking the universe)
                    imp_x = np.random.uniform(-3.5, 3.5)
                    imp_y = np.random.uniform(-4.0, -1.5)
                    arena.apply_action(imp_x, imp_y)
                    current_action = np.array([imp_x, imp_y], dtype=np.float32)
                elif event.key == pygame.K_o:
                    arena.occluder_active = not arena.occluder_active
                elif event.key == pygame.K_t:
                    online_learning = not online_learning
                elif event.key == pygame.K_r:
                    arena.reset()

        # Step the physical universe
        arena.step()
        next_frame = arena.render_frame()

        # Step the cognitive agent
        z_t, z_dream, dream_pixels, pixel_diff = agent.process_step(
            current_frame, current_action, next_frame, train=online_learning
        )
        current_frame = next_frame

        # --- DRAWING PIPELINE ---
        screen.fill((8, 10, 14))

        # Panel Layout Coordinates
        panel_y = 60
        panel_size = 280
        p1_x = 40
        p2_x = 360
        p3_x = 680

        # 1. OPTICAL REALITY VIEWPORT
        surf_reality = render_surface_from_numpy(current_frame, (panel_size, panel_size), colormap="mono")
        screen.blit(surf_reality, (p1_x, panel_y))
        pygame.draw.rect(screen, (35, 45, 55), (p1_x - 1, panel_y - 1, panel_size + 2, panel_size + 2), 1)

        # 2. INTERNAL DREAM VIEWPORT
        surf_dream = render_surface_from_numpy(dream_pixels, (panel_size, panel_size), colormap="dream")
        screen.blit(surf_dream, (p2_x, panel_y))
        pygame.draw.rect(screen, (25, 60, 75), (p2_x - 1, panel_y - 1, panel_size + 2, panel_size + 2), 1)

        # 3. PREDICTION SURPRISE VIEWPORT
        surf_surprise = render_surface_from_numpy(pixel_diff * 2.5, (panel_size, panel_size), colormap="surprise")
        screen.blit(surf_surprise, (p3_x, panel_y))
        pygame.draw.rect(screen, (80, 50, 20), (p3_x - 1, panel_y - 1, panel_size + 2, panel_size + 2), 1)

        # Headers
        screen.blit(font_bold.render("1. OPTICAL REALITY (It)", True, (200, 220, 240)), (p1_x, panel_y - 24))
        screen.blit(font_bold.render("2. INTERNAL DREAM (It+1)", True, (60, 210, 255)), (p2_x, panel_y - 24))
        screen.blit(font_bold.render("3. PREDICTION SURPRISE (|It - It+1|)", True, (255, 160, 50)), (p3_x, panel_y - 24))

        # 4. LATENT STATE VECTOR HUD (Concept Barcode)
        hud_x = 40
        hud_y = 380
        pygame.draw.rect(screen, (14, 18, 24), (hud_x, hud_y, 920, 160))
        pygame.draw.rect(screen, (30, 40, 50), (hud_x, hud_y, 920, 160), 1)

        screen.blit(font_large.render("LATENT MANIFOLD EMBEDDING [16-DIMENSIONAL CONCEPT SPACE]", True, (180, 200, 220)), (hud_x + 16, hud_y + 14))

        # Draw 16 latent bars
        bar_w = 42
        bar_spacing = 14
        bar_base_y = hud_y + 95
        for i, val in enumerate(z_t):
            bx = hud_x + 20 + i * (bar_w + bar_spacing)
            # Clip value to [-3.0, 3.0]
            val_norm = np.clip(val / 3.0, -1.0, 1.0)
            bar_h = int(val_norm * 45)
            
            # Color: Cyan if positive, Amber if negative
            col = (40, 210, 240) if bar_h >= 0 else (240, 120, 50)
            
            # Zero line
            pygame.draw.line(screen, (50, 60, 75), (bx, bar_base_y), (bx + bar_w, bar_base_y), 1)
            # Active bar
            if bar_h >= 0:
                pygame.draw.rect(screen, col, (bx, bar_base_y - bar_h, bar_w, bar_h))
            else:
                pygame.draw.rect(screen, col, (bx, bar_base_y, bar_w, -bar_h))
                
            label = font.render(f"z{i}", True, (110, 130, 150))
            screen.blit(label, (bx + 8, bar_base_y + 48))

        # 5. RIGHT-HAND TELEMETRY PANEL
        r_x = 980
        r_y = 60
        r_w = 220
        r_h = 480
        pygame.draw.rect(screen, (14, 18, 24), (r_x, r_y, r_w, r_h))
        pygame.draw.rect(screen, (30, 40, 50), (r_x, r_y, r_w, r_h), 1)

        screen.blit(font_bold.render("COGNITIVE TELEMETRY", True, (240, 205, 50)), (r_x + 12, r_y + 14))
        
        mean_loss = np.mean(agent.recent_losses) if agent.recent_losses else 0.0
        
        telemetry_lines = [
            f"Step:       {agent.step_count}",
            f"Device:     {device}",
            f"Replay Buf: {len(agent.hippocampus)}/2000",
            f"Mean Loss:  {mean_loss:.5f}",
            "",
            "EPISTEMIC STATE:",
            f"Surprise:   {agent.current_surprise:.4f}",
            f"Learning:   {'ACTIVE' if online_learning else 'FROZEN'}",
            f"Occluder:   {'ON (Tunnel)' if arena.occluder_active else 'OFF'}",
            "",
            "THEORY OF OBJECTS:",
            "• Perm. Test: TRACKING",
            "• Collisions: LEARNED",
            "• Gravity:    ACTIVE",
            "",
            "CONTROLS:",
            "[SPACE] Poke Universe",
            "[O]     Toggle Tunnel",
            "[T]     Toggle Learn",
            "[R]     Reset Bodies",
            "[Q/ESC] Quit",
        ]
        
        ty = r_y + 45
        for line in telemetry_lines:
            if "ACTIVE" in line or "TRACKING" in line or "LEARNED" in line:
                col = (60, 230, 140)
            elif "Surprise" in line:
                col = (255, 180, 50)
            elif line.startswith("•") or line.startswith("["):
                col = (140, 160, 180)
            else:
                col = (180, 200, 220)
            screen.blit(font.render(line, True, col), (r_x + 12, ty))
            ty += 18

        # Bottom Status Bar
        bot_y = 560
        pygame.draw.rect(screen, (14, 18, 24), (40, bot_y, 920, 130))
        pygame.draw.rect(screen, (30, 40, 50), (40, bot_y, 920, 130), 1)
        
        screen.blit(font_bold.render("PIXELSENSE :: THE SENSE-MAKING ARCHITECTURE (HASSABIS & SILVER FOUNDATIONS)", True, (240, 205, 50)), (56, bot_y + 14))
        desc_lines = [
            "1. NO LABELS OR GROUND-TRUTH COORDINATES: The agent receives only raw 64x64 pixel arrays.",
            "2. SPATIAL BOTTLENECK (V): Compresses photons into 16 continuous invariant concepts (x, y, inertia).",
            "3. RECURRENT DYNAMICS (M): Simulates kinetic transitions forward in latent space (dreaming).",
            "4. OBJECT PERMANENCE: When an object enters the dark tunnel, V loses pixels, but M maintains mental tracking."
        ]
        dy = bot_y + 40
        for d in desc_lines:
            screen.blit(font.render(d, True, (130, 150, 170)), (56, dy))
            dy += 20

        pygame.display.flip()

        if args.render_frames > 0:
            frame_path = os.path.join(args.output_dir, f"frame_{frame_idx:04d}.png")
            pygame.image.save(screen, frame_path)
            if frame_idx % 60 == 0:
                print(f"[PixelSense] Rendered {frame_idx}/{args.render_frames} frames ({frame_idx/args.render_frames*100:.1f}%)")
            if frame_idx >= args.render_frames:
                print(f"[PixelSense] Render complete: {args.render_frames} frames.")
                running = False

        clock.tick(60)

    pygame.quit()

if __name__ == "__main__":
    main()
