import json
import subprocess
import sys


def test_ping_and_shutdown():
    proc = subprocess.Popen([sys.executable, '-m', 'chino_inference'], stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, cwd='inference_runtime')
    assert proc.stdin and proc.stdout
    proc.stdin.write(json.dumps({'protocol': 1, 'request_id': '1', 'action': 'ping'}) + '\n'); proc.stdin.flush()
    pong = json.loads(proc.stdout.readline())
    assert pong['ok'] is True and pong['request_id'] == '1' and pong['action'] == 'ping'
    proc.stdin.write(json.dumps({'protocol': 1, 'request_id': '2', 'action': 'shutdown'}) + '\n'); proc.stdin.flush()
    bye = json.loads(proc.stdout.readline())
    assert bye['ok'] is True
    proc.wait(timeout=5); assert proc.returncode == 0
