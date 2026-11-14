# tool_data/vcs/Makefile — compilação e execução RTL com VCS
# Autores: Alanna Santos e Apolonio Neto. Projeto da dupla na residência CI Expert,
# polo UFCG (trilha de Physical Design), 2026.
#
# Passo 1 — compilar:  make compile
# Passo 2 — executar:  make run FIRMWARE=../../verif/sw/hello.hex
# Combinado:           make sim  FIRMWARE=../../verif/sw/hello.hex
# Com forma de onda:   make gui  FIRMWARE=../../verif/sw/hello.hex
#
# O Makefile usa caminhos relativos à raiz do repositório (REPO_ROOT).
# REPO_ROOT é detectado pelo git, então funciona de qualquer diretório.

REPO_ROOT  := $(shell git rev-parse --show-toplevel)
TB_DIR     := $(REPO_ROOT)/third_party/cv32e40p/example_tb/core
BHV_DIR    := $(REPO_ROOT)/third_party/cv32e40p/bhv
FLIST_RTL  := $(REPO_ROOT)/tool_data/vcs/flist_rtl.f
SIMV       := $(REPO_ROOT)/tool_data/vcs/simv
WORK_DIR   := $(REPO_ROOT)/tool_data/vcs/csrc
FIRMWARE   ?= $(REPO_ROOT)/verif/sw/hello.hex
DUMP_TCL   := $(REPO_ROOT)/tool_data/vcs/dump.tcl
WAVE_FSDB  := $(REPO_ROOT)/tool_data/vcs/wave.fsdb

# Sem isso, "comando | tee arquivo.log" sempre "passa" pro make mesmo se o
# comando da esquerda falhar (make só olha o status do último da pipe, que é
# o tee). Com -o pipefail, qualquer falha na pipe derruba a receita inteira —
# por exemplo, se o ambiente das ferramentas Synopsys não estiver carregado
# nesta sessão de shell ("vcs: command not found"), o make para na hora em
# vez de seguir como se tivesse compilado.
SHELL      := /bin/bash
.SHELLFLAGS := -eu -o pipefail -c

# Flags do VCS explicadas:
#   -full64            → obrigatório: só existe binário de 64 bits no servidor
#   -sverilog          → ativa suporte a SystemVerilog (além de Verilog puro)
#   -timescale=1ns/1ps → unidade de tempo / precisão da simulação
#   -debug_access+all  → libera acesso a todos os sinais (necessário para Verdi)
#   -kdb               → gera banco de dados do Verdi (formas de onda com hierarquia)
#   -top tb_top        → módulo topo da hierarquia de simulação
VCS_FLAGS := \
    -full64 \
    -sverilog \
    -timescale=1ns/1ps \
    -debug_access+all \
    -kdb \
    -top tb_top

# Arquivos do testbench que não estão no manifesto RTL.
# O testbench do OpenHW tem uma RAM (dp_ram), um periférico de stdout (mm_ram),
# um subsistema que conecta o núcleo à memória, e pequenos módulos de estímulo.
TB_FILES := \
    $(TB_DIR)/include/perturbation_pkg.sv \
    $(TB_DIR)/cv32e40p_random_interrupt_generator.sv \
    $(TB_DIR)/tb_top.sv \
    $(TB_DIR)/cv32e40p_tb_subsystem.sv \
    $(TB_DIR)/dp_ram.sv \
    $(TB_DIR)/mm_ram.sv \
    $(TB_DIR)/amo_shim.sv \
    $(TB_DIR)/riscv_gnt_stall.sv \
    $(TB_DIR)/riscv_rvalid_stall.sv

# Diretórios de include do testbench (onde o VCS procura os .svh incluídos)
TB_INCDIRS := \
    +incdir+$(TB_DIR) \
    +incdir+$(BHV_DIR) \
    +incdir+$(BHV_DIR)/include

.PHONY: compile run sim gui wave verdi clean flist

# Gera a filelist a partir do manifesto do OpenHW
flist:
	$(REPO_ROOT)/scripts/gen_filelist.sh

# Compilação do RTL + testbench → gera o executável 'simv'
compile: flist
	vcs $(VCS_FLAGS) \
	    -file $(FLIST_RTL) \
	    $(TB_INCDIRS) \
	    $(TB_FILES) \
	    -o $(SIMV) \
	    2>&1 | tee compile.log
	@echo ""
	@echo "=== Compilação concluída. Executável: $(SIMV) ==="
	@echo "=== Para rodar: make run FIRMWARE=../../verif/sw/hello.hex ==="

# Execução em linha de comando (sem interface gráfica)
run: $(SIMV)
	$(SIMV) \
	    +firmware=$(FIRMWARE) \
	    +verbose \
	    2>&1 | tee run.log

# Compilação + execução numa tacada só
sim: compile run

# Execução com interface gráfica do Verdi conectada ao vivo (precisa de
# sessão gráfica ativa durante a simulação inteira)
gui: $(SIMV)
	$(SIMV) \
	    +firmware=$(FIRMWARE) \
	    +verbose \
	    -gui &

# Gera o banco de formas de onda (wave.fsdb) rodando a simulação em modo
# batch (sem interface gráfica), via script UCLI (dump.tcl). Não precisa de
# sessão gráfica nesta etapa — só quando for abrir o Verdi depois.
wave: $(SIMV)
	$(SIMV) \
	    +firmware=$(FIRMWARE) \
	    +verbose \
	    -ucli -i $(DUMP_TCL) \
	    2>&1 | tee wave.log
	@echo ""
	@echo "=== Forma de onda gerada: $(WAVE_FSDB) ==="
	@echo "=== Para abrir: make verdi ==="

# Abre o Verdi com a forma de onda já gerada (precisa de sessão gráfica
# ativa só agora, não durante a simulação)
verdi: $(WAVE_FSDB)
	verdi -ssf $(WAVE_FSDB) &

# Remove todos os artefatos gerados (não apaga o hex em verif/sw/)
clean:
	rm -rf $(SIMV) $(WORK_DIR) $(FLIST_RTL) \
	       compile.log run.log wave.log *.vcd *.fsdb \
	       ucli.key vc_hdrs.h

$(SIMV): compile

$(WAVE_FSDB): wave
