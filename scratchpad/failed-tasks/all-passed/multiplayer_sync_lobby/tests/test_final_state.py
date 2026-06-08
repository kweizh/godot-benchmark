import os
import time
import pytest
import socket
from xprocess import ProcessStarter

PROJECT_DIR = "/home/user/godot-benchmark"

class ServerStarter(ProcessStarter):
    name = "godot_server"
    args = ["godot", "--headless", "--path", PROJECT_DIR, "--", "--server"]
    env = os.environ.copy()
    popen_kwargs = {
        "cwd": PROJECT_DIR,
        "text": True,
    }
    
    def startup_check(self):
        # Allow time for server initialization
        time.sleep(2.0)
        return True

class Client1Starter(ProcessStarter):
    name = "godot_client1"
    args = ["godot", "--headless", "--path", PROJECT_DIR, "--", "--client", "--name", "Alice"]
    env = os.environ.copy()
    popen_kwargs = {
        "cwd": PROJECT_DIR,
        "text": True,
    }
    
    def startup_check(self):
        # Allow time for client initialization
        time.sleep(2.0)
        return True

class Client2Starter(ProcessStarter):
    name = "godot_client2"
    args = ["godot", "--headless", "--path", PROJECT_DIR, "--", "--client", "--name", "Bob"]
    env = os.environ.copy()
    popen_kwargs = {
        "cwd": PROJECT_DIR,
        "text": True,
    }
    
    def startup_check(self):
        # Allow time for client initialization
        time.sleep(2.0)
        return True

def read_log(xprocess, name):
    log_path = xprocess.getinfo(name).logpath
    if os.path.exists(log_path):
        with open(log_path, "r") as f:
            return f.read()
    return ""

def test_multiplayer_lobby_sync(xprocess):
    """
    Test multiplayer lobby synchronization:
    1. Start the headless Godot server.
    2. Start Client 1 and verify connection.
    3. Start Client 2 and verify connection.
    4. Verify player scenes are spawned and position/name properties are synchronized.
    """
    # 1. Start Server
    xprocess.ensure("godot_server", ServerStarter)
    time.sleep(2.0)
    
    server_log = read_log(xprocess, "godot_server")
    assert "server" in server_log.lower() or "started" in server_log.lower() or "listen" in server_log.lower(), \
        f"Server did not log startup. Server log:\n{server_log}"
        
    # 2. Start Client 1
    xprocess.ensure("godot_client1", Client1Starter)
    time.sleep(2.0)
    
    client1_log = read_log(xprocess, "godot_client1")
    assert "connect" in client1_log.lower() or "join" in client1_log.lower(), \
        f"Client 1 did not log connection. Client 1 log:\n{client1_log}"
        
    server_log = read_log(xprocess, "godot_server")
    assert "connect" in server_log.lower() or "peer" in server_log.lower(), \
        f"Server did not log Client 1 connection. Server log:\n{server_log}"
    assert "spawn" in server_log.lower() or "player" in server_log.lower(), \
        f"Server did not log player spawning. Server log:\n{server_log}"
        
    # 3. Start Client 2
    xprocess.ensure("godot_client2", Client2Starter)
    time.sleep(2.0)
    
    client2_log = read_log(xprocess, "godot_client2")
    assert "connect" in client2_log.lower() or "join" in client2_log.lower(), \
        f"Client 2 did not log connection. Client 2 log:\n{client2_log}"
        
    server_log = read_log(xprocess, "godot_server")
    assert server_log.lower().count("connect") + server_log.lower().count("peer") >= 2, \
        f"Server did not log both client connections. Server log:\n{server_log}"
        
    # 4. Verify Synchronization
    # Wait for movement and synchronization to occur
    time.sleep(4.0)
    
    server_log = read_log(xprocess, "godot_server")
    client1_log = read_log(xprocess, "godot_client1")
    client2_log = read_log(xprocess, "godot_client2")
    
    # Ensure logs contain synchronization indicators (position, name, or sync)
    assert "position" in server_log.lower() or "sync" in server_log.lower() or "pos" in server_log.lower(), \
        f"Server log does not show synchronized position updates. Server log:\n{server_log}"
        
    assert "position" in client1_log.lower() or "sync" in client1_log.lower() or "pos" in client1_log.lower(), \
        f"Client 1 log does not show synchronized position updates. Client 1 log:\n{client1_log}"
        
    assert "position" in client2_log.lower() or "sync" in client2_log.lower() or "pos" in client2_log.lower(), \
        f"Client 2 log does not show synchronized position updates. Client 2 log:\n{client2_log}"

    # Cleanup processes
    xprocess.getinfo("godot_client2").terminate()
    xprocess.getinfo("godot_client1").terminate()
    xprocess.getinfo("godot_server").terminate()
