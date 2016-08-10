.PHONY: pip

REQUIREMENTS=\
	     flask \
	     django \
	     tornado \
	     flake8 \
	     autopep8 \
	     neovim \
	     boto3

pip:
	pip install --upgrade $(REQUIREMENTS)
