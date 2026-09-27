import os
import glob
import json
import pandas as pd
import matplotlib.pyplot as plt
import seaborn as sns

sns.set_theme(style="whitegrid")
plt.rcParams['figure.figsize'] = (10, 6)

INPUT_DIR = "results/raw"
OUTPUT_DIR = "results/graficos"
os.makedirs(OUTPUT_DIR, exist_ok=True)

print("Iniciando geração de gráficos...")

json_files = glob.glob(f"{INPUT_DIR}/*.json")
if json_files:
    dados_a = []
    for f in json_files:
        try:
            with open(f, 'r') as file:
                data = json.load(file)
                basename = os.path.basename(f)
                rate = int(basename.split('_')[1].replace('M', ''))
                
                sum_data = data['end']['sum']
                vazao_mbps = sum_data['bits_per_second'] / 1e6
                perda_pct = sum_data.get('lost_percent', 0.0)
                
                dados_a.append({'Taxa_Configurada_Mbps': rate, 'Vazao_Real_Mbps': vazao_mbps, 'Perda_Pacotes_%': perda_pct})
        except Exception:
            pass

    if dados_a:
        df_a = pd.DataFrame(dados_a)
        
        plt.figure()
        sns.lineplot(data=df_a, x='Taxa_Configurada_Mbps', y='Vazao_Real_Mbps', marker='o', errorbar='sd')
        plt.plot([df_a['Taxa_Configurada_Mbps'].min(), df_a['Taxa_Configurada_Mbps'].max()], 
                 [df_a['Taxa_Configurada_Mbps'].min(), df_a['Taxa_Configurada_Mbps'].max()], 
                 'r--', label='Ideal (Taxa = Vazão)')
        plt.title('Cenário A: Vazão UDP Real vs Configurada')
        plt.ylabel('Vazão Medida (Mbps)')
        plt.xlabel('Taxa Configurável do iperf3 (Mbps)')
        plt.legend()
        plt.savefig(f"{OUTPUT_DIR}/cenario_a_vazao.png", dpi=300)
        plt.close()
        print("- Gráfico Cenário A (Vazão) gerado.")

csv_b = f"{INPUT_DIR}/cenario_b_metrics.csv"
if os.path.exists(csv_b):
    df_b = pd.read_csv(csv_b)
    df_b['time_total'] = pd.to_numeric(df_b['time_total'], errors='coerce')
    
    plt.figure()
    ordem_arquivos = ['testfile_100M.bin', 'testfile_500M.bin', 'testfile_1G.bin']
    sns.barplot(data=df_b, x='file', y='time_total', hue='protocol', order=ordem_arquivos, errorbar='sd', capsize=0.1)
    plt.title('Cenário B: Tempo Total de Download por Protocolo')
    plt.ylabel('Tempo Total (segundos)')
    plt.xlabel('Tamanho do Arquivo')
    plt.savefig(f"{OUTPUT_DIR}/cenario_b_tempo_total.png", dpi=300)
    plt.close()
    print("- Gráfico Cenário B (Arquivos Grandes) gerado.")

csv_c_batch = f"{INPUT_DIR}/cenario_c_batch.csv"
if os.path.exists(csv_c_batch):
    df_c_batch = pd.read_csv(csv_c_batch)
    df_c_batch['total_time_s'] = pd.to_numeric(df_c_batch['total_time_s'], errors='coerce')
    
    plt.figure(figsize=(8,6))
    sns.barplot(data=df_c_batch, x='protocol', y='total_time_s', errorbar='sd', capsize=0.1, palette='Set2')
    plt.title('Cenário C: Download Concorrente (100 objetos) com Alta Latência/Perda')
    plt.ylabel('Tempo Total do Lote (segundos)')
    plt.xlabel('Protocolo')
    plt.savefig(f"{OUTPUT_DIR}/cenario_c_lote_concorrente.png", dpi=300)
    plt.close()
    print("- Gráfico Cenário C (Lote de Objetos) gerado.")

csv_c_reconnect = f"{INPUT_DIR}/cenario_c_reconnect.csv"
if os.path.exists(csv_c_reconnect):
    df_c_rec = pd.read_csv(csv_c_reconnect)
    df_c_rec['time_total'] = pd.to_numeric(df_c_rec['time_total'], errors='coerce')
    
    plt.figure(figsize=(8,6))
    sns.boxplot(data=df_c_rec, x='protocol', y='time_total', palette='Set3')
    plt.title('Cenário C: Tempo de Handshake/Reconexão Isolada')
    plt.ylabel('Tempo Total da Requisição (segundos)')
    plt.xlabel('Protocolo')
    plt.savefig(f"{OUTPUT_DIR}/cenario_c_reconexao_isolada.png", dpi=300)
    plt.close()
    print("- Gráfico Cenário C (Reconexão/Handshake) gerado.")

print(f"\nFinalizado! As imagens foram salvas na pasta: {OUTPUT_DIR}/")
