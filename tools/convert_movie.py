from pathlib import Path
import subprocess
import imageio_ffmpeg
root=Path(__file__).resolve().parents[1]
subprocess.run([imageio_ffmpeg.get_ffmpeg_exe(), '-y', '-i', str(root/'builds/garden-walkthrough.avi'),
    '-c:v', 'libx264', '-preset', 'medium', '-crf', '23', '-pix_fmt', 'yuv420p',
    '-c:a', 'aac', '-b:a', '128k', '-movflags', '+faststart', str(root/'builds/garden-walkthrough.mp4')], check=True)
