#!/usr/bin/env python3
"""
Todo MCP Server - A fast SQLite-backed todo list server for the Model Context Protocol
"""
import json
import sys
import sqlite3
import os
from pathlib import Path
from typing import Dict, Any, List, Optional

class TodoDatabase:
    def __init__(self, db_path: str):
        self.db_path = db_path
        self.ensure_db_exists()
    
    def ensure_db_exists(self):
        Path(self.db_path).parent.mkdir(parents=True, exist_ok=True)
        conn = sqlite3.connect(self.db_path)
        conn.execute("""
            CREATE TABLE IF NOT EXISTS todos (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                content TEXT NOT NULL,
                done BOOLEAN DEFAULT FALSE,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
        """)
        conn.commit()
        conn.close()
    
    def get_all(self) -> List[Dict[str, Any]]:
        conn = sqlite3.connect(self.db_path)
        conn.row_factory = sqlite3.Row
        cursor = conn.execute("SELECT * FROM todos ORDER BY done ASC, created_at ASC")
        todos = [dict(row) for row in cursor.fetchall()]
        conn.close()
        return todos
    
    def add(self, content: str) -> int:
        conn = sqlite3.connect(self.db_path)
        cursor = conn.execute("INSERT INTO todos (content) VALUES (?)", (content,))
        todo_id = cursor.lastrowid
        conn.commit()
        conn.close()
        return todo_id
    
    def update(self, todo_id: int, content: Optional[str] = None, done: Optional[bool] = None) -> bool:
        conn = sqlite3.connect(self.db_path)
        updates = []
        params = []
        
        if content is not None:
            updates.append("content = ?")
            params.append(content)
        if done is not None:
            updates.append("done = ?")
            params.append(done)
        
        if not updates:
            return False
        
        updates.append("updated_at = CURRENT_TIMESTAMP")
        params.append(todo_id)
        
        query = f"UPDATE todos SET {', '.join(updates)} WHERE id = ?"
        cursor = conn.execute(query, params)
        success = cursor.rowcount > 0
        conn.commit()
        conn.close()
        return success
    
    def delete(self, todo_id: int) -> bool:
        conn = sqlite3.connect(self.db_path)
        cursor = conn.execute("DELETE FROM todos WHERE id = ?", (todo_id,))
        success = cursor.rowcount > 0
        conn.commit()
        conn.close()
        return success

class MCPServer:
    def __init__(self, db_path: str):
        self.db = TodoDatabase(db_path)
        self.tools = {
            "list_todos": self.list_todos,
            "add_todo": self.add_todo,
            "update_todo": self.update_todo,
            "delete_todo": self.delete_todo,
        }
    
    def list_todos(self, **kwargs) -> Dict[str, Any]:
        """List all todo items"""
        todos = self.db.get_all()
        return {"todos": todos}
    
    def add_todo(self, content: str, **kwargs) -> Dict[str, Any]:
        """Add a new todo item"""
        todo_id = self.db.add(content)
        return {"id": todo_id, "success": True}
    
    def update_todo(self, id: int, content: Optional[str] = None, done: Optional[bool] = None, **kwargs) -> Dict[str, Any]:
        """Update a todo item"""
        success = self.db.update(id, content, done)
        return {"success": success}
    
    def delete_todo(self, id: int, **kwargs) -> Dict[str, Any]:
        """Delete a todo item"""
        success = self.db.delete(id)
        return {"success": success}
    
    def handle_request(self, request: Dict[str, Any]) -> Dict[str, Any]:
        method = request.get("method")
        
        if method == "initialize":
            return {
                "protocolVersion": "2024-11-05",
                "capabilities": {
                    "tools": {}
                },
                "serverInfo": {
                    "name": "todo-mcp",
                    "version": "1.0.0"
                }
            }
        
        elif method == "tools/list":
            tools = []
            for name, func in self.tools.items():
                tool_def = {
                    "name": name,
                    "description": func.__doc__.strip() if func.__doc__ else "",
                    "inputSchema": {
                        "type": "object",
                        "properties": {}
                    }
                }
                
                # Define input schemas
                if name == "add_todo":
                    tool_def["inputSchema"]["properties"]["content"] = {
                        "type": "string",
                        "description": "The todo item content"
                    }
                    tool_def["inputSchema"]["required"] = ["content"]
                elif name == "update_todo":
                    tool_def["inputSchema"]["properties"] = {
                        "id": {"type": "integer", "description": "The todo item ID"},
                        "content": {"type": "string", "description": "New content (optional)"},
                        "done": {"type": "boolean", "description": "Mark as done/undone (optional)"}
                    }
                    tool_def["inputSchema"]["required"] = ["id"]
                elif name == "delete_todo":
                    tool_def["inputSchema"]["properties"]["id"] = {
                        "type": "integer",
                        "description": "The todo item ID to delete"
                    }
                    tool_def["inputSchema"]["required"] = ["id"]
                
                tools.append(tool_def)
            
            return {"tools": tools}
        
        elif method == "tools/call":
            tool_name = request.get("params", {}).get("name")
            arguments = request.get("params", {}).get("arguments", {})
            
            if tool_name in self.tools:
                try:
                    result = self.tools[tool_name](**arguments)
                    return result
                except Exception as e:
                    return {"error": str(e)}
            else:
                return {"error": f"Tool not found: {tool_name}"}
        
        else:
            return {"error": f"Unknown method: {method}"}
    
    def run(self):
        # Read JSON-RPC messages from stdin and write responses to stdout
        while True:
            try:
                line = sys.stdin.readline()
                if not line:
                    break
                
                request = json.loads(line.strip())
                response = self.handle_request(request)
                
                # Add JSON-RPC fields
                response["jsonrpc"] = "2.0"
                if "id" in request:
                    response["id"] = request["id"]
                
                # Write response
                sys.stdout.write(json.dumps(response) + "\n")
                sys.stdout.flush()
                
            except json.JSONDecodeError:
                # Invalid JSON, skip
                continue
            except KeyboardInterrupt:
                break
            except Exception as e:
                # Send error response
                error_response = {
                    "jsonrpc": "2.0",
                    "error": {
                        "code": -32603,
                        "message": "Internal error",
                        "data": str(e)
                    }
                }
                if "id" in locals() and "request" in locals() and "id" in request:
                    error_response["id"] = request["id"]
                
                sys.stdout.write(json.dumps(error_response) + "\n")
                sys.stdout.flush()

if __name__ == "__main__":
    # Default database path
    db_path = os.path.expanduser("~/.local/share/nvim/todo-mcp.db")
    
    # Allow overriding via environment variable
    if "TODO_MCP_DB" in os.environ:
        db_path = os.environ["TODO_MCP_DB"]
    
    server = MCPServer(db_path)
    server.run()