FROM rocker/r-ver:4.4.1

RUN apt-get clean all && \
	apt-get update && \
	apt-get upgrade -y && \
	apt-get install -y \
		python3 \
		python-is-python3 \
		python3-pip \
	&& apt-get clean all && \
	apt-get purge && \
	rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

RUN pip install --upgrade gget
RUN R -q -e 'install.packages(c("optparse", "pheatmap", "dplyr", "tidyr"))'

RUN mkdir /opt/bin
ENV PATH="$PATH:/opt/bin"

COPY script/heatmap.R script/plot_heatmap.sh /opt/bin

ENTRYPOINT ["plot_heatmap.sh"]
