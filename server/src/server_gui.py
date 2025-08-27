import tkinter as tk
from tkinter import ttk, scrolledtext, messagebox
import asyncio
import threading
from game_server import GameServer

class ServerGUI:
    def __init__(self):
        self.root = tk.Tk()
        self.root.title("Projeto Ally - Servidor Multiplayer")
        self.root.geometry("800x600")
        self.root.resizable(True, True)
        
        # Servidor
        self.server = GameServer()
        self.server.set_log_callback(self.add_log)
        self.server_thread = None
        self.loop = None
        
        # Interface
        self.setup_ui()
        
        # Status inicial
        self.update_status()
    
    def setup_ui(self):
        """Configura a interface gráfica"""
        # Título
        title_frame = ttk.Frame(self.root)
        title_frame.pack(fill="x", padx=10, pady=5)
        
        title_label = ttk.Label(
            title_frame, 
            text="🎮 PROJETO ALLY - SERVIDOR MULTIPLAYER", 
            font=("Arial", 16, "bold")
        )
        title_label.pack()
        
        # Frame de controles
        control_frame = ttk.LabelFrame(self.root, text="Controles do Servidor")
        control_frame.pack(fill="x", padx=10, pady=5)
        
        # Botões
        buttons_frame = ttk.Frame(control_frame)
        buttons_frame.pack(fill="x", padx=5, pady=5)
        
        self.start_button = ttk.Button(
            buttons_frame, 
            text="🚀 Ligar Servidor", 
            command=self.start_server,
            style="Success.TButton"
        )
        self.start_button.pack(side="left", padx=5)
        
        self.stop_button = ttk.Button(
            buttons_frame, 
            text="🛑 Desligar Servidor", 
            command=self.stop_server,
            state="disabled"
        )
        self.stop_button.pack(side="left", padx=5)
        
        self.restart_button = ttk.Button(
            buttons_frame, 
            text="Reiniciar Servidor", 
            command=self.restart_server,
            state="disabled"
        )
        self.restart_button.pack(side="left", padx=5)
        
        # Frame de status
        status_frame = ttk.LabelFrame(self.root, text="Status do Servidor")
        status_frame.pack(fill="x", padx=10, pady=5)
        
        self.status_text = ttk.Label(
            status_frame, 
            text="🔴 Servidor Desligado", 
            font=("Arial", 12, "bold")
        )
        self.status_text.pack(padx=5, pady=5)
        
        # Informações detalhadas
        info_frame = ttk.Frame(status_frame)
        info_frame.pack(fill="x", padx=5, pady=5)
        
        self.connections_label = ttk.Label(info_frame, text="Conexões: 0")
        self.connections_label.pack(side="left", padx=10)
        
        self.players_label = ttk.Label(info_frame, text="Jogadores: 0")
        self.players_label.pack(side="left", padx=10)
        
        self.address_label = ttk.Label(info_frame, text="Endereço: ws://localhost:8765")
        self.address_label.pack(side="left", padx=10)
        
        # Frame de configurações
        config_frame = ttk.LabelFrame(self.root, text="Configurações")
        config_frame.pack(fill="x", padx=10, pady=5)
        
        config_grid = ttk.Frame(config_frame)
        config_grid.pack(fill="x", padx=5, pady=5)
        
        ttk.Label(config_grid, text="Host:").grid(row=0, column=0, sticky="w", padx=5)
        self.host_entry = ttk.Entry(config_grid, width=15)
        self.host_entry.insert(0, "localhost")
        self.host_entry.grid(row=0, column=1, padx=5)
        
        ttk.Label(config_grid, text="Porta:").grid(row=0, column=2, sticky="w", padx=5)
        self.port_entry = ttk.Entry(config_grid, width=10)
        self.port_entry.insert(0, "8765")
        self.port_entry.grid(row=0, column=3, padx=5)
        
        # Frame de logs
        log_frame = ttk.LabelFrame(self.root, text="Logs do Servidor")
        log_frame.pack(fill="both", expand=True, padx=10, pady=5)
        
        self.log_text = scrolledtext.ScrolledText(
            log_frame, 
            height=15, 
            font=("Consolas", 9)
        )
        self.log_text.pack(fill="both", expand=True, padx=5, pady=5)
        
        # Botão limpar logs
        clear_button = ttk.Button(
            log_frame, 
            text="🗑️ Limpar Logs", 
            command=self.clear_logs
        )
        clear_button.pack(side="right", padx=5, pady=5)
        
        # Frame de jogadores online
        players_frame = ttk.LabelFrame(self.root, text="Jogadores Online")
        players_frame.pack(fill="x", padx=10, pady=5)
        
        self.players_listbox = tk.Listbox(players_frame, height=4)
        self.players_listbox.pack(fill="x", padx=5, pady=5)
        
        # Configurar evento de fechamento
        self.root.protocol("WM_DELETE_WINDOW", self.on_closing)
        
        # Iniciar update loop
        self.update_loop()
    
    def add_log(self, message):
        """Adiciona mensagem ao log"""
        self.root.after(0, lambda: self._add_log_safe(message))
    
    def _add_log_safe(self, message):
        """Adiciona log de forma thread-safe"""
        self.log_text.insert(tk.END, message + "\n")
        self.log_text.see(tk.END)
        
        # Limitar linhas do log
        lines = self.log_text.get("1.0", tk.END).count('\n')
        if lines > 1000:
            self.log_text.delete("1.0", "100.0")
    
    def clear_logs(self):
        """Limpa os logs"""
        self.log_text.delete("1.0", tk.END)
    
    def start_server(self):
        """Inicia o servidor"""
        if self.server.running:
            return
        
        # Atualizar configurações
        self.server.host = self.host_entry.get() or "localhost"
        self.server.port = int(self.port_entry.get() or "8765")
        
        # Iniciar servidor em thread separada
        self.server_thread = threading.Thread(target=self._start_server_thread)
        self.server_thread.daemon = True
        self.server_thread.start()
    
    def _start_server_thread(self):
        """Thread do servidor"""
        self.loop = asyncio.new_event_loop()
        asyncio.set_event_loop(self.loop)
        
        try:
            success = self.loop.run_until_complete(self.server.start_server())
            if success:
                self.root.after(0, self._on_server_started)
                # Manter o loop rodando
                self.loop.run_forever()
        except Exception as e:
            self.add_log(f"Erro critico no servidor: {e}")
        finally:
            self.loop.close()
    
    def _on_server_started(self):
        """Callback quando servidor inicia"""
        self.start_button.config(state="disabled")
        self.stop_button.config(state="normal")
        self.restart_button.config(state="normal")
        self.host_entry.config(state="disabled")
        self.port_entry.config(state="disabled")
    
    def stop_server(self):
        """Para o servidor"""
        try:
            self.add_log("Parando servidor...")
            
            # Marcar servidor como não rodando
            if self.server:
                self.server.running = False
            
            # Parar thread se existir
            if self.server_thread and self.server_thread.is_alive():
                self.server_thread.join(timeout=3)
            
            # Fechar loop se existir
            if self.loop and not self.loop.is_closed():
                if self.loop.is_running():
                    self.loop.call_soon_threadsafe(self.loop.stop)
                try:
                    self.loop.close()
                except:
                    pass
            
            self._on_server_stopped()
            self.add_log("Servidor parado com sucesso")
            
        except Exception as e:
            self.add_log(f"Erro ao parar servidor: {e}")
            self._on_server_stopped()
    
    def _on_server_stopped(self):
        """Callback quando servidor para"""
        self.start_button.config(state="normal")
        self.stop_button.config(state="disabled")
        self.restart_button.config(state="disabled")
        self.host_entry.config(state="normal")
        self.port_entry.config(state="normal")
        self.players_listbox.delete(0, tk.END)
        self.server_thread = None
        self.loop = None
    
    def restart_server(self):
        """Reinicia o servidor"""
        self.add_log("Reiniciando servidor...")
        self.stop_server()
        
        # Aguardar um pouco e reiniciar
        self.root.after(2000, self.start_server)
    
    def update_button_states(self):
        """Atualiza o estado dos botões baseado no status do servidor"""
        if self.server and self.server.running:
            self.start_button.config(state="disabled")
            self.stop_button.config(state="normal")
            self.restart_button.config(state="normal")
            self.host_entry.config(state="disabled")
            self.port_entry.config(state="disabled")
        else:
            self.start_button.config(state="normal")
            self.stop_button.config(state="disabled")
            self.restart_button.config(state="disabled")
            self.host_entry.config(state="normal")
            self.port_entry.config(state="normal")
    
    def update_status(self):
        """Atualiza o status na interface"""
        status = self.server.get_status()
        
        if status["running"]:
            self.status_text.config(
                text="Servidor Online", 
                foreground="green"
            )
        else:
            self.status_text.config(
                text="Servidor Desligado", 
                foreground="red"
            )
        
        # Atualizar estado dos botões
        self.update_button_states()
        
        self.connections_label.config(text=f"Conexões: {status['clients_connected']}")
        self.players_label.config(text=f"Jogadores: {status['players_online']}")
        self.address_label.config(text=f"Endereço: ws://{status['host']}:{status['port']}")
        
        # Atualizar lista de jogadores
        self.players_listbox.delete(0, tk.END)
        for player_id, player_info in self.server.players.items():
            self.players_listbox.insert(tk.END, f"{player_info['name']} (ID: {player_id[:8]})")
    
    def update_loop(self):
        """Loop de atualização da interface"""
        self.update_status()
        self.root.after(1000, self.update_loop)  # Atualizar a cada segundo
    
    def on_closing(self):
        """Callback de fechamento da janela"""
        try:
            if self.server and self.server.running:
                if messagebox.askokcancel("Fechar", "Servidor está rodando. Deseja parar e fechar?"):
                    self.force_stop_server()
                    self.root.quit()
                    self.root.destroy()
            else:
                self.root.quit()
                self.root.destroy()
        except Exception as e:
            print(f"Erro ao fechar: {e}")
            self.root.quit()
            self.root.destroy()
    
    def force_stop_server(self):
        """Para o servidor forçadamente"""
        try:
            if self.server and self.server.running:
                self.server.running = False
                if hasattr(self.server, 'websocket_server') and self.server.websocket_server:
                    self.server.websocket_server.close()
                if self.server_thread and self.server_thread.is_alive():
                    # Dar tempo para o thread parar
                    self.server_thread.join(timeout=2)
                self.add_log("Servidor parado forçadamente")
                self.update_button_states()
        except Exception as e:
            print(f"Erro ao parar servidor: {e}")
    
    def run(self):
        """Executa a interface"""
        self.add_log("Interface do Servidor Iniciada")
        self.add_log("Para iniciar o servidor, clique em 'Ligar Servidor'")
        self.root.mainloop()

if __name__ == "__main__":
    app = ServerGUI()
    app.run()