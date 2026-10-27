"""
latent_dynamics.py - Recurrent Latent World Model (M)
Learns the causal physics and kinematics of the universe purely in abstract latent space.
Predicts z_{t+1} given current z_t, action a_t, and recurrent memory h_t.
Allows the agent to mentally simulate (dream) unvisited futures.
"""

import torch
import torch.nn as nn

class LatentWorldModel(nn.Module):
    def __init__(self, latent_dim=16, action_dim=2, hidden_dim=64):
        super().__init__()
        self.latent_dim = latent_dim
        self.action_dim = action_dim
        self.hidden_dim = hidden_dim
        
        # Input: current latent state z_t + action a_t
        self.input_proj = nn.Sequential(
            nn.Linear(latent_dim + action_dim, hidden_dim),
            nn.LayerNorm(hidden_dim),
            nn.LeakyReLU(0.1, inplace=True)
        )
        
        # Recurrent Core: GRUCell capturing momentum, trajectory, and multi-step dynamics
        self.rnn = nn.GRUCell(hidden_dim, hidden_dim)
        
        # Transition Predictor: predicts latent velocity / delta: z_{t+1} = z_t + Delta z
        self.delta_head = nn.Sequential(
            nn.Linear(hidden_dim, hidden_dim),
            nn.LeakyReLU(0.1, inplace=True),
            nn.Linear(hidden_dim, latent_dim)
        )
        
        # Uncertainty / Confidence Head: estimates epistemic confidence
        self.confidence_head = nn.Sequential(
            nn.Linear(hidden_dim, 1),
            nn.Sigmoid()
        )

    def init_hidden(self, batch_size=1, device="cpu"):
        return torch.zeros(batch_size, self.hidden_dim, device=device)

    def forward_step(self, z_t, a_t, h_prev):
        """
        One forward step inside the internal model of reality:
        Predicts z_{t+1} from z_t and hypothetical action a_t.
        """
        inp = torch.cat([z_t, a_t], dim=-1)
        feat = self.input_proj(inp)
        h_next = self.rnn(feat, h_prev)
        delta_z = self.delta_head(h_next)
        z_next = z_t + delta_z  # Residual transition
        conf = self.confidence_head(h_next)
        return z_next, h_next, conf

    def rollout_dream(self, z_start, action_sequence, h_start=None):
        """
        Multi-step imagination: Hallucinates K steps into the future
        entirely within the agent's internal latent space.
        """
        device = z_start.device
        if h_start is None:
            h_curr = self.init_hidden(z_start.size(0), device=device)
        else:
            h_curr = h_start

        dreamed_latents = []
        z_curr = z_start
        
        for a_step in action_sequence:
            z_curr, h_curr, _ = self.forward_step(z_curr, a_step, h_curr)
            dreamed_latents.append(z_curr)
            
        return torch.stack(dreamed_latents, dim=1), h_curr
