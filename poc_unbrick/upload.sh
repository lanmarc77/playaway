#!/bin/bash

sbtools/elftosb -z -c test.db -o test.sb
sbtools/sbloader test.sb
