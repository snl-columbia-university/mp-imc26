# NB: By default fetch the paper from Google docs every time
# use "make recompile" to avoid the extra fetch


# USAGE PYTHON=python_path make
# python_path should be python3.x, with libraries in requirements.txt instaled
# i.e., before running make do python_path -m pip install -r requirements.txt
#
# (PYTHON is set from shell env variable, or with this default value)
PYTHON ?= python

NAME=mp_latency
TARGET=$(NAME).pdf


# This is the document ID of your google doc
# (SETTING UP) An author should create a project on the google cloud console
# The author should add the accounts of everyone else to the project
# ** I THINK ** everyone can use the same drive_api_key.json file (in git), but this may not be true
# ***** THE ACCOUNT YOU ADD SHOULD ONLY HAVE VIEW PERMISSIONS OF THE FILE *******
DOCS_LINK=https://docs.google.com/document/d/1VWcS26FoXVeMZ1B66evPaFLhm33qDnUT_6eLVYcE1Ao/export?format=txt

# This line should not change; however, you can customize the template.tex for the conference
#
# We use "--tab-stop 3" as Google Docs indents nested lists with three spaces
# (for markup, it's normally 4)
PANDOC_FLAGS=-s -N --template=template.tex -f markdown+yaml_metadata_block+footnotes -t latex --tab-stop 3

# Customize the line below to change the bib file and the csl file (either ieee or acm)
# and to use pandoc-citeproc or biblatex (the latter is the default)
# BIBLIO_FLAGS=--bibliography=mybib.bib --csl=acm.csl
BIBLIO_FLAGS=--bibliography=mybib.bib --natbib

.SUFFIXES:
.SUFFIXES: .stamp .tex .pdf

UNAME_S := $(shell uname -s)
ifeq ($(UNAME_S),Darwin)
	SED_REGEXP_FLAGS += -E
endif

top: all

recompile: $(TARGET)

all: trigger $(TARGET)

clean:
	# rm -f $(NAME).aux $(NAME).bbl $(NAME).blg $(NAME).log $(NAME).pdf $(NAME).md $(NAME).mdg $(NAME).mdt $(NAME).md-r $(NAME).out $(NAME).trig $(NAME).run.xml $(NAME)-blx.bib authors.aux
	rm -f $(NAME).aux $(NAME).bbl $(NAME).blg $(NAME).log $(NAME).pdf $(NAME).md $(NAME).mdg $(NAME).md-r $(NAME).out $(NAME).trig $(NAME).run.xml $(NAME)-blx.bib authors.aux
	rm -f $(NAME).tex  # CAUTION remove if source is moved from Google docs

trigger $(NAME).trig:
	touch $(NAME).trig

# This fetches the shared source from Google docs
$(NAME).tex: $(NAME).trig
	# Get's the document via the google docs API
	# the first time you do this, you will need to authenticate via your browser
	# just log into the google account you added to the project (see above)
	# $(PYTHON) pull_doc.py $(NAME) $(DOC_ID)
	wget --no-check-certificate -O$(NAME).mdt $(DOCS_LINK)
	# `awk '{if (/^#/) print ""; print $0}'` adds a new line before any
	#  section heading (begins with #)
	iconv -c -t ASCII//TRANSLIT $(NAME).mdt | awk '{if (/^#/) print ""; print $0}' > $(NAME).md
	# Footnote support for Google Docs
	#   - `s/\[([0-9]+)\]/\[^\1\]/g` adds a `^` to the beginning of
	#      Google Docs footnote marks ([1] -> [^1])
	#   - `s/^(\[\^[0-9]+\])/\1:/g` adds a `:` after the closing bracket
	#      for footnote marks at the beginning of the line, which is used
	#      when defining the footnote's text at the end of the textfile
	#      exported from Google Docs
	#   - `s/^_{16}//` trims the ______________ that appears before
	#      the footnotes in Google Docs text export
	sed -i -r $(SED_REGEXP_FLAGS) 's/\[([0-9]+)\]/\[^\1\]/g; s/^(\[\^[0-9]+\])/\1:/g; s/^_{16}//' $(NAME).md
	rm $(NAME).mdt
	pandoc $(PANDOC_FLAGS) $(BIBLIO_FLAGS) $(NAME).md > $(NAME).tex~
	# Refs go before appendix (if any), not after.  Fix Hackily (manually move stuff around) fix that here.
	if grep '\\appendix' <$(NAME).tex~; \
	then { < $(NAME).tex~ sed -e '/^\\appendix/,$$d' ; \
	  < $(NAME).tex~ grep '\\bibliography{'; \
	  < $(NAME).tex~ grep '^\\appendix'; \
	  < $(NAME).tex~ sed -e '1,/^\\appendix/d' -e '/\\bibliography{/d'  ; \
	} > $(NAME).tex; \
	else cp $(NAME).tex~ $(NAME).tex; \
	fi
	# Google docs now include comments inside of [letter], so remove that.
	sed -i'orig' 's/[{][[][}][a-z].*[{][]][}]//g' $(NAME).tex

# Iterate on latex until cross references don't change
$(NAME).pdf: $(NAME).tex
	pdflatex $(NAME)
	bibtex $(NAME)
	pdflatex $(NAME)
	pdflatex $(NAME)

spell: $(NAME).tex
	cat $(NAME).tex | aspell list | sort -u | aspell -a
