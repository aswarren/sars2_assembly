TOP_DIR = ../..
include $(TOP_DIR)/tools/Makefile.common

DEPLOY_RUNTIME ?= /kb/runtime
TARGET ?= /kb/deployment

APP_SERVICE = app_service

SRC_PERL = $(wildcard scripts/*.pl)
BIN_PERL = $(addprefix $(BIN_DIR)/,$(basename $(notdir $(SRC_PERL))))
DEPLOY_PERL = $(addprefix $(TARGET)/bin/,$(basename $(notdir $(SRC_PERL))))

SRC_SERVICE_PERL = $(wildcard service-scripts/*.pl)
BIN_SERVICE_PERL = $(addprefix $(BIN_DIR)/,$(basename $(notdir $(SRC_SERVICE_PERL))))
DEPLOY_SERVICE_PERL = $(addprefix $(SERVICE_DIR)/bin/,$(basename $(notdir $(SRC_SERVICE_PERL))))

CLIENT_TESTS = $(wildcard t/client-tests/*.t)
SERVER_TESTS = $(wildcard t/server-tests/*.t)
PROD_TESTS = $(wildcard t/prod-tests/*.t)

STARMAN_WORKERS = 8
STARMAN_MAX_REQUESTS = 100

TPAGE_ARGS = --define kb_top=$(TARGET) --define kb_runtime=$(DEPLOY_RUNTIME) --define kb_service_name=$(SERVICE) \
	--define kb_service_port=$(SERVICE_PORT) --define kb_service_dir=$(SERVICE_DIR) \
	--define kb_sphinx_port=$(SPHINX_PORT) --define kb_sphinx_host=$(SPHINX_HOST) \
	--define kb_starman_workers=$(STARMAN_WORKERS) \
	--define kb_starman_max_requests=$(STARMAN_MAX_REQUESTS)

PRIMER_SRC = https://raw.githubusercontent.com/CDCgov/SARS-CoV-2_Sequencing/master/protocols/CDC-Comprehensive/Multiplex_PCR/SC2_200324.bedpe

all: bin primer artic_schemes reference

bin: $(BIN_PERL) $(BIN_SERVICE_PERL)

reference: lib/Bio/P3/SARS2Assembly/MN908947.fasta.fai

lib/Bio/P3/SARS2Assembly/MN908947.fasta.fai: lib/Bio/P3/SARS2Assembly/MN908947.fasta
	bowtie2-build  lib/Bio/P3/SARS2Assembly/MN908947.fasta lib/Bio/P3/SARS2Assembly/MN908947.fasta
	$(KB_RUNTIME)/samtools-1.9/bin/samtools faidx lib/Bio/P3/SARS2Assembly/MN908947.fasta

primer: lib/Bio/P3/SARS2Assembly/SC2_200324.bedpe

lib/Bio/P3/SARS2Assembly/SC2_200324.bedpe:
	curl -o $@ -L $(PRIMER_SRC)

artic_schemes: lib/Bio/P3/SARS2Assembly/primer_schemes

lib/Bio/P3/SARS2Assembly/primer_schemes:
	rm -rf artic-ncov2019
	git clone https://github.com/artic-network/artic-ncov2019.git
	cp -r artic-ncov2019/primer_schemes lib/Bio/P3/SARS2Assembly

deploy: deploy-all
deploy-all: deploy-client 
deploy-client: deploy-libs deploy-scripts deploy-docs
deploy-service: deploy-dir deploy-service-scripts

deploy-service-scripts:
	export KB_TOP=$(TARGET); \
	export KB_RUNTIME=$(DEPLOY_RUNTIME); \
	export KB_PERL_PATH=$(TARGET)/lib ; \
	for src in $(SRC_SERVICE_PERL) ; do \
	        basefile=`basename $$src`; \
	        base=`basename $$src .pl`; \
	        echo install $$src $$base ; \
	        cp $$src $(TARGET)/plbin ; \
	        $(WRAP_PERL_SCRIPT) "$(TARGET)/plbin/$$basefile" $(TARGET)/bin/$$base ; \
	done 
	mkdir -p $(TARGET)/services/$(APP_SERVICE)
	rsync -arv app_specs $(TARGET)/services/$(APP_SERVICE)/.

deploy-dir:
	if [ ! -d $(SERVICE_DIR) ] ; then mkdir $(SERVICE_DIR) ; fi
	if [ ! -d $(SERVICE_DIR)/bin ] ; then mkdir $(SERVICE_DIR)/bin ; fi

deploy-docs: 


clean:


$(BIN_DIR)/%: service-scripts/%.pl $(TOP_DIR)/user-env.sh
	$(WRAP_PERL_SCRIPT) '$$KB_TOP/modules/$(CURRENT_DIR)/$<' $@

$(BIN_DIR)/%: service-scripts/%.py $(TOP_DIR)/user-env.sh
	$(WRAP_PYTHON_SCRIPT) '$$KB_TOP/modules/$(CURRENT_DIR)/$<' $@

include $(TOP_DIR)/tools/Makefile.common.rules
