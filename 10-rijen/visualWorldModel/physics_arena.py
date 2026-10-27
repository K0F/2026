"""
physics_arena.py - Ground-Truth Kinematic Optical Environment
Generates pure raster pixel frames (64x64) from interacting physical bodies,
elastic boundaries, friction, and an opaque occluder (testing object permanence).
No ground truth coordinates are ever leaked to the cognitive agent.
"""

import numpy as np

class PhysicsArena:
    def __init__(self, width=64, height=64, num_bodies=2):
        self.w = width
        self.h = height
        self.num_bodies = num_bodies
        
        # Bodies state: [x, y, vx, vy, radius, brightness]
        self.bodies = []
        self.reset()
        
        # Opaque Occluder / Blind Tunnel (Testing Object Permanence)
        # Objects passing behind this barrier become invisible in raw pixels
        self.occluder_active = True
        self.occluder_x1 = 26
        self.occluder_x2 = 38
        
        # External perturbing force (agent agency / mouse interaction)
        self.external_impulse = np.array([0.0, 0.0], dtype=np.float32)

    def reset(self):
        self.bodies = []
        for i in range(self.num_bodies):
            radius = 3.5 if i == 0 else 2.8
            brightness = 1.0 if i == 0 else 0.8
            x = np.random.uniform(10, self.w - 10)
            y = np.random.uniform(10, self.h - 10)
            angle = np.random.uniform(0, 2 * np.pi)
            speed = np.random.uniform(1.2, 2.2)
            vx = np.cos(angle) * speed
            vy = np.sin(angle) * speed
            self.bodies.append({
                'x': float(x), 'y': float(y),
                'vx': float(vx), 'vy': float(vy),
                'r': float(radius), 'b': float(brightness)
            })

    def apply_action(self, fx, fy):
        """External agent / sensory probe action (Perturbation)"""
        self.external_impulse[0] += fx
        self.external_impulse[1] += fy

    def step(self):
        """Simulate kinematic updates and elastic boundary reflections"""
        # Apply impulse to primary body (Body 0)
        if np.linalg.norm(self.external_impulse) > 1e-4:
            self.bodies[0]['vx'] += self.external_impulse[0]
            self.bodies[0]['vy'] += self.external_impulse[1]
            self.external_impulse *= 0.2  # Damping

        for b in self.bodies:
            # Gravity / downward drift
            b['vy'] += 0.02
            
            # Update position
            b['x'] += b['vx']
            b['y'] += b['vy']
            
            # Boundary bounce (elastic with slight damping)
            if b['x'] - b['r'] <= 1:
                b['x'] = 1 + b['r']
                b['vx'] = -b['vx'] * 0.95
            elif b['x'] + b['r'] >= self.w - 2:
                b['x'] = self.w - 2 - b['r']
                b['vx'] = -b['vx'] * 0.95

            if b['y'] - b['r'] <= 1:
                b['y'] = 1 + b['r']
                b['vy'] = -b['vy'] * 0.95
            elif b['y'] + b['r'] >= self.h - 2:
                b['y'] = self.h - 2 - b['r']
                b['vy'] = -b['vy'] * 0.95

        # Body-to-body elastic collision
        if len(self.bodies) >= 2:
            b1, b2 = self.bodies[0], self.bodies[1]
            dx = b2['x'] - b1['x']
            dy = b2['y'] - b1['y']
            dist = np.sqrt(dx*dx + dy*dy)
            min_dist = b1['r'] + b2['r']
            if dist < min_dist and dist > 1e-5:
                # Normal vector
                nx = dx / dist
                ny = dy / dist
                # Relative velocity
                kx = b1['vx'] - b2['vx']
                ky = b1['vy'] - b2['vy']
                p = 2 * (nx * kx + ny * ky) / 2.0  # Equal mass
                b1['vx'] -= p * nx
                b1['vy'] -= p * ny
                b2['vx'] += p * nx
                b2['vy'] += p * ny
                # Separate overlap
                overlap = 0.5 * (min_dist - dist)
                b1['x'] -= overlap * nx
                b1['y'] -= overlap * ny
                b2['x'] += overlap * nx
                b2['y'] += overlap * ny

    def render_frame(self):
        """
        Renders the current physical reality to raw pixel array [64, 64] float in [0.0, 1.0].
        This is the ONLY information the agent ever receives.
        """
        frame = np.zeros((self.h, self.w), dtype=np.float32)
        
        # 1. Arena borders
        frame[0, :] = 0.25
        frame[-1, :] = 0.25
        frame[:, 0] = 0.25
        frame[:, -1] = 0.25

        # 2. Render smooth anti-aliased bodies
        y_grid, x_grid = np.ogrid[:self.h, :self.w]
        for b in self.bodies:
            d2 = (x_grid - b['x'])**2 + (y_grid - b['y'])**2
            r2 = b['r']**2
            # Smooth circular falloff (anti-aliased disc)
            mask = np.clip(1.0 - (d2 - r2*0.6) / (r2*0.6 + 1e-5), 0.0, 1.0)
            frame = np.maximum(frame, mask * b['b'])

        # 3. Apply Opaque Occluder / Blind Tunnel
        if self.occluder_active:
            # Dark barrier column
            frame[:, self.occluder_x1:self.occluder_x2] = 0.03
            # Fine demarcation boundaries
            frame[:, self.occluder_x1] = 0.15
            frame[:, self.occluder_x2 - 1] = 0.15

        return frame
