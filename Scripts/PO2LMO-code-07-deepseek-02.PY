import tkinter as tk
from tkinter import filedialog, messagebox, ttk
import os
import sys
import subprocess
import threading
import platform
import traceback
from tkinter.scrolledtext import ScrolledText

# 检查并安装必要的依赖
def install_dependencies():
    try:
        from po2lmo import parse_po_file, write_lmo_file
        return True
    except ImportError:
        try:
            import pip
            pip.main(['install', 'po2lmo'])
            from po2lmo import parse_po_file, write_lmo_file
            return True
        except:
            return False

class POtoLMOConverter:
    def __init__(self, root):
        self.root = root
        self.root.title("OpenWrt PO 到 LMO 批量转换工具")
        self.root.geometry("900x700")
        self.root.resizable(True, True)
        
        # 设置应用图标
        try:
            self.root.iconbitmap("icon.ico")
        except:
            pass
        
        # 创建样式
        self.style = ttk.Style()
        self.style.configure("TFrame", background="#f0f0f0")
        self.style.configure("TButton", font=("Arial", 10), padding=5)
        self.style.configure("TLabel", background="#f0f0f0", font=("Arial", 10))
        self.style.configure("Header.TLabel", font=("Arial", 14, "bold"), foreground="#2c3e50")
        self.style.configure("Status.TLabel", font=("Arial", 9), foreground="#555555")
        self.style.configure("Success.TLabel", font=("Arial", 9), foreground="#27ae60")
        
        # 检查依赖
        if not install_dependencies():
            messagebox.showerror("依赖错误", "无法安装 po2lmo 库，请手动安装：pip install po2lmo")
            self.root.destroy()
            return
            
        # 创建主框架
        self.main_frame = ttk.Frame(root, padding=20)
        self.main_frame.pack(fill=tk.BOTH, expand=True)
        
        # 创建标题
        self.header = ttk.Label(
            self.main_frame, 
            text="OpenWrt PO 到 LMO 批量转换工具", 
            style="Header.TLabel"
        )
        self.header.pack(pady=(0, 15))
        
        # 添加说明文本
        explanation = ttk.Label(
            self.main_frame,
            text="此工具使用 po2lmo 库进行批量转换，完全兼容原始仓库逻辑。\n"
                 "支持选择多个 PO 文件同时转换，输出文件保存在指定目录。",
            justify=tk.CENTER,
            wraplength=800
        )
        explanation.pack(pady=(0, 15))
        
        # 创建文件选择区域
        file_frame = ttk.LabelFrame(self.main_frame, text="文件选择")
        file_frame.pack(fill=tk.X, pady=10, padx=5)
        
        # PO 文件列表
        ttk.Label(file_frame, text="选择 PO 文件:").grid(row=0, column=0, sticky=tk.W, padx=(10, 5), pady=5)
        self.po_files = []
        self.file_listbox = tk.Listbox(file_frame, width=80, height=8, selectmode=tk.EXTENDED)
        self.file_listbox.grid(row=0, column=1, rowspan=3, sticky=tk.NSEW, padx=5, pady=5)
        
        # 文件操作按钮框架
        file_btn_frame = ttk.Frame(file_frame)
        file_btn_frame.grid(row=0, column=2, rowspan=3, sticky=tk.NS, padx=(0, 10), pady=5)
        
        # 添加文件按钮
        self.add_file_btn = ttk.Button(file_btn_frame, text="添加文件", command=self.add_po_files, width=12)
        self.add_file_btn.pack(pady=5)
        
        # 添加文件夹按钮
        self.add_folder_btn = ttk.Button(file_btn_frame, text="添加文件夹", command=self.add_po_folder, width=12)
        self.add_folder_btn.pack(pady=5)
        
        # 清空列表按钮
        self.clear_btn = ttk.Button(file_btn_frame, text="清空列表", command=self.clear_file_list, width=12)
        self.clear_btn.pack(pady=5)
        
        # 文件数量标签
        self.file_count_var = tk.StringVar(value="已选择 0 个文件")
        ttk.Label(file_frame, textvariable=self.file_count_var).grid(row=3, column=1, sticky=tk.W, padx=10, pady=5)
        
        # 输出目录区域
        output_frame = ttk.LabelFrame(self.main_frame, text="输出设置")
        output_frame.pack(fill=tk.X, pady=10, padx=5)
        
        # 输出目录选择
        ttk.Label(output_frame, text="输出目录:").grid(row=0, column=0, sticky=tk.W, padx=(10, 5), pady=5)
        self.output_dir = tk.StringVar()
        output_entry = ttk.Entry(output_frame, textvariable=self.output_dir, width=80)
        output_entry.grid(row=0, column=1, sticky=tk.EW, padx=5, pady=5)
        output_button = ttk.Button(output_frame, text="浏览...", command=self.select_output_dir, width=10)
        output_button.grid(row=0, column=2, padx=(0, 10), pady=5)
        
        # 文件名模式
        ttk.Label(output_frame, text="输出文件名:").grid(row=1, column=0, sticky=tk.W, padx=(10, 5), pady=5)
        self.name_pattern_var = tk.StringVar(value="同名.lmo文件")
        name_pattern_frame = ttk.Frame(output_frame)
        name_pattern_frame.grid(row=1, column=1, columnspan=2, sticky=tk.W, padx=5, pady=5)
        
        ttk.Radiobutton(
            name_pattern_frame, 
            text="同名.lmo文件 (推荐)", 
            variable=self.name_pattern_var, 
            value="同名.lmo文件"
        ).pack(side=tk.LEFT, padx=5)
        
        ttk.Radiobutton(
            name_pattern_frame, 
            text="自定义前缀", 
            variable=self.name_pattern_var, 
            value="自定义前缀"
        ).pack(side=tk.LEFT, padx=5)
        
        self.custom_prefix = tk.StringVar()
        custom_entry = ttk.Entry(name_pattern_frame, textvariable=self.custom_prefix, width=20, state=tk.DISABLED)
        custom_entry.pack(side=tk.LEFT, padx=5)
        
        # 绑定事件
        self.name_pattern_var.trace_add("write", self.update_custom_entry_state)
        
        # 操作按钮区域
        btn_frame = ttk.Frame(self.main_frame)
        btn_frame.pack(fill=tk.X, pady=15)
        
        # 转换按钮
        self.convert_button = ttk.Button(
            btn_frame, 
            text="开始批量转换", 
            command=self.start_conversion,
            style="TButton",
            width=20
        )
        self.convert_button.pack(side=tk.LEFT, padx=20)
        
        # 打开文件夹按钮
        self.open_button = ttk.Button(
            btn_frame, 
            text="打开输出文件夹", 
            command=self.open_output_folder,
            state=tk.DISABLED,
            width=20
        )
        self.open_button.pack(side=tk.LEFT, padx=20)
        
        # 状态信息
        self.status_var = tk.StringVar(value="就绪")
        status_frame = ttk.Frame(self.main_frame)
        status_frame.pack(fill=tk.X, pady=(0, 5))
        ttk.Label(status_frame, text="状态:").pack(side=tk.LEFT, padx=(10, 5))
        status_label = ttk.Label(
            status_frame, 
            textvariable=self.status_var, 
            style="Status.TLabel"
        )
        status_label.pack(side=tk.LEFT, fill=tk.X, expand=True)
        
        # 进度条
        self.progress_var = tk.IntVar(value=0)
        self.progress = ttk.Progressbar(
            self.main_frame, 
            orient=tk.HORIZONTAL, 
            length=500, 
            mode='determinate',
            variable=self.progress_var
        )
        self.progress.pack(fill=tk.X, pady=(0, 10), padx=10)
        
        # 日志区域
        log_frame = ttk.LabelFrame(self.main_frame, text="转换日志")
        log_frame.pack(fill=tk.BOTH, expand=True, pady=5, padx=5)
        
        self.log_text = ScrolledText(
            log_frame, 
            wrap=tk.WORD, 
            font=("Consolas", 9),
            height=15
        )
        self.log_text.pack(fill=tk.BOTH, expand=True, padx=5, pady=5)
        self.log_text.config(state=tk.DISABLED)
        
        # 添加版本信息
        version_frame = ttk.Frame(self.main_frame)
        version_frame.pack(fill=tk.X, pady=(5, 0))
        
        ttk.Label(
            version_frame, 
            text="PO to LMO Converter v4.0 | 批量转换工具 | 使用 po2lmo 库 1.0.0", 
            style="Status.TLabel"
        ).pack(side=tk.LEFT)
        
        ttk.Label(
            version_frame, 
            text="github.com/stevenjoezhang/po2lmo.py", 
            style="Status.TLabel"
        ).pack(side=tk.RIGHT)
        
        # 设置网格列权重
        file_frame.columnconfigure(1, weight=1)
        output_frame.columnconfigure(1, weight=1)
        
        # 存储当前转换的文件路径
        self.current_output_dir = None
        self.conversion_in_progress = False
        
    def log_message(self, message):
        """添加消息到日志区域"""
        self.log_text.config(state=tk.NORMAL)
        self.log_text.insert(tk.END, message + "\n")
        self.log_text.see(tk.END)
        self.log_text.config(state=tk.DISABLED)
        self.status_var.set(message)
        
    def update_file_count(self):
        """更新文件数量显示"""
        count = len(self.po_files)
        self.file_count_var.set(f"已选择 {count} 个文件")
        
    def add_po_files(self):
        """添加 PO 文件到列表"""
        file_paths = filedialog.askopenfilenames(
            title="选择 PO 文件",
            filetypes=[("PO 语言包文件", "*.po"), ("所有文件", "*.*")]
        )
        if file_paths:
            new_files = [path for path in file_paths if path not in self.po_files]
            self.po_files.extend(new_files)
            
            # 更新列表显示
            self.file_listbox.delete(0, tk.END)
            for file in self.po_files:
                self.file_listbox.insert(tk.END, os.path.basename(file))
            
            self.update_file_count()
            self.log_message(f"添加了 {len(new_files)} 个文件")
    
    def add_po_folder(self):
        """添加文件夹中的所有 PO 文件"""
        dir_path = filedialog.askdirectory(title="选择包含 PO 文件的文件夹")
        if dir_path:
            po_files = []
            for root, _, files in os.walk(dir_path):
                for file in files:
                    if file.lower().endswith('.po'):
                        po_files.append(os.path.join(root, file))
            
            if not po_files:
                self.log_message("在选择的文件夹中未找到 PO 文件")
                return
                
            new_files = [path for path in po_files if path not in self.po_files]
            self.po_files.extend(new_files)
            
            # 更新列表显示
            self.file_listbox.delete(0, tk.END)
            for file in self.po_files:
                self.file_listbox.insert(tk.END, os.path.basename(file))
            
            self.update_file_count()
            self.log_message(f"从文件夹添加了 {len(new_files)} 个 PO 文件")
    
    def clear_file_list(self):
        """清空文件列表"""
        if not self.po_files:
            return
            
        if messagebox.askyesno("确认", "确定要清空文件列表吗？"):
            self.po_files = []
            self.file_listbox.delete(0, tk.END)
            self.update_file_count()
            self.log_message("已清空文件列表")
    
    def select_output_dir(self):
        """选择输出目录"""
        dir_path = filedialog.askdirectory(title="选择输出目录")
        if dir_path:
            self.output_dir.set(dir_path)
            self.current_output_dir = dir_path
            self.log_message(f"输出目录设置为: {dir_path}")
    
    def update_custom_entry_state(self, *args):
        """更新自定义前缀输入框状态"""
        if self.name_pattern_var.get() == "自定义前缀":
            self.custom_prefix.config(state=tk.NORMAL)
        else:
            self.custom_prefix.config(state=tk.DISABLED)
    
    def start_conversion(self):
        """开始批量转换过程"""
        if not self.po_files:
            messagebox.showwarning("警告", "请先选择要转换的 PO 文件！")
            return
            
        output_dir = self.output_dir.get()
        if not output_dir:
            messagebox.showwarning("警告", "请指定输出目录！")
            return
            
        if not os.path.isdir(output_dir):
            try:
                os.makedirs(output_dir)
                self.log_message(f"创建输出目录: {output_dir}")
            except Exception as e:
                messagebox.showerror("错误", f"无法创建输出目录:\n{str(e)}")
                return
        
        # 检查是否已有转换在进行
        if self.conversion_in_progress:
            messagebox.showwarning("警告", "转换正在进行中，请等待完成")
            return
            
        self.conversion_in_progress = True
        
        # 禁用按钮
        self.convert_button.config(state=tk.DISABLED)
        self.add_file_btn.config(state=tk.DISABLED)
        self.add_folder_btn.config(state=tk.DISABLED)
        self.clear_btn.config(state=tk.DISABLED)
        self.open_button.config(state=tk.DISABLED)
        
        # 清空日志
        self.log_text.config(state=tk.NORMAL)
        self.log_text.delete(1.0, tk.END)
        self.log_text.config(state=tk.DISABLED)
        
        self.log_message("开始批量转换...")
        self.log_message(f"共 {len(self.po_files)} 个文件需要转换")
        self.log_message(f"输出目录: {output_dir}")
        
        # 使用线程进行转换，避免UI冻结
        threading.Thread(
            target=self.batch_convert_files, 
            daemon=True
        ).start()
    
    def batch_convert_files(self):
        """批量转换文件"""
        try:
            total_files = len(self.po_files)
            success_count = 0
            output_dir = self.output_dir.get()
            
            for idx, po_path in enumerate(self.po_files):
                # 更新状态
                self.status_var.set(f"正在转换文件 {idx+1}/{total_files}")
                self.progress_var.set(int((idx / total_files) * 100))
                self.root.update()
                
                # 确定输出文件名
                if self.name_pattern_var.get() == "同名.lmo文件":
                    filename = os.path.basename(po_path)
                    if filename.lower().endswith('.po'):
                        filename = filename[:-3] + '.lmo'
                else:
                    prefix = self.custom_prefix.get().strip()
                    if not prefix:
                        prefix = "output"
                    filename = f"{prefix}_{idx+1}.lmo"
                
                output_path = os.path.join(output_dir, filename)
                
                # 记录开始
                self.log_message(f"\n=== 开始转换: {os.path.basename(po_path)} ===")
                self.log_message(f"输出文件: {filename}")
                
                # 执行转换
                if self.convert_single_file(po_path, output_path):
                    success_count += 1
                    self.log_message(f"转换成功: {os.path.basename(po_path)} -> {filename}")
                else:
                    self.log_message(f"转换失败: {os.path.basename(po_path)}")
            
            # 更新进度条
            self.progress_var.set(100)
            
            # 显示结果
            self.log_message("\n===== 批量转换完成 =====")
            self.log_message(f"成功: {success_count} 个文件")
            self.log_message(f"失败: {total_files - success_count} 个文件")
            self.log_message(f"输出目录: {output_dir}")
            
            # 启用打开文件夹按钮
            self.open_button.config(state=tk.NORMAL)
            self.current_output_dir = output_dir
            
            # 显示完成消息
            messagebox.showinfo("完成", f"批量转换完成!\n成功: {success_count} 个文件\n失败: {total_files - success_count} 个文件")
            
        except Exception as e:
            self.log_message(f"批量转换过程中出错: {str(e)}\n{traceback.format_exc()}")
            messagebox.showerror("错误", f"批量转换过程中发生错误:\n{str(e)}")
        finally:
            # 重新启用按钮
            self.convert_button.config(state=tk.NORMAL)
            self.add_file_btn.config(state=tk.NORMAL)
            self.add_folder_btn.config(state=tk.NORMAL)
            self.clear_btn.config(state=tk.NORMAL)
            self.status_var.set("批量转换完成")
            self.conversion_in_progress = False
    
    def convert_single_file(self, po_path, output_path):
        """转换单个文件"""
        try:
            # 使用 po2lmo 库进行转换
            from po2lmo import parse_po_file, write_lmo_file
            
            # 解析PO文件
            entries = parse_po_file(po_path)
            self.log_message(f"找到 {len(entries)} 个翻译条目")
            
            # 写入LMO文件
            write_lmo_file(entries, output_path)
            
            return True
            
        except Exception as e:
            self.log_message(f"转换失败: {str(e)}")
            return False
    
    def open_output_folder(self):
        """打开输出文件夹"""
        output_dir = self.current_output_dir or self.output_dir.get()
        if output_dir and os.path.isdir(output_dir):
            try:
                # Windows
                if platform.system() == "Windows":
                    os.startfile(output_dir)
                # macOS
                elif platform.system() == "Darwin":
                    subprocess.Popen(["open", output_dir])
                # Linux
                else:
                    subprocess.Popen(["xdg-open", output_dir])
            except Exception as e:
                self.log_message(f"无法打开文件夹: {str(e)}")
                messagebox.showerror("错误", f"无法打开文件夹:\n{str(e)}")
        else:
            messagebox.showwarning("警告", "输出目录不存在或未设置！")

if __name__ == "__main__":
    root = tk.Tk()
    app = POtoLMOConverter(root)
    root.mainloop()