.PHONY: all clean purge

all:	all-urls

clean:
	-rm -f nlmmain-urls nlmmain-wget seniorhealth-urls seniorhealth-wget
	-rm -rf www.nlm.nih.gov nihseniorhealth.gov

purge: clean
	-rm -f all-urls

all-urls: nlmmain-urls seniorhealth-urls
	cat nlmmain-urls seniorhealth-urls > all-urls

nlmmain-urls: must-haves crawl-nlmmain
	./crawl-nlmmain

seniorhealth-urls: crawl-seniorhealth
	./crawl-seniorhealth


