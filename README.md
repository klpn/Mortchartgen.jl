# Mortchartgen

[![Build Status](https://travis-ci.org/klpn/Mortchartgen.jl.svg?branch=master)](https://travis-ci.org/klpn/Mortchartgen.jl)

[![Coverage Status](https://coveralls.io/repos/klpn/Mortchartgen.jl/badge.svg?branch=master&service=github)](https://coveralls.io/github/klpn/Mortchartgen.jl?branch=master)

[![codecov.io](http://codecov.io/github/klpn/Mortchartgen.jl/coverage.svg?branch=master)](http://codecov.io/github/klpn/Mortchartgen.jl?branch=master)

This package can be used to generate charts of mortality trends from the WHO
Mortality Database, as well as web templates and documentation for these charts. 
It is a reimplementation of the
[mortchartgen](https://github.com/klpn/mortchartgen) program, which uses Python and R
for chart generation. I use the package the generate my site with mortality
charts, which is available in [English](http://mortchart-en.klpn.se/) and
[Swedish](http://mortchart.klpn.se) versions.

Besides the Julia requirements, generation of the site requires the following:

1. Access to a MySQL/MariaDB database server for storing the WHO data.
2. The Python [Bokeh](https://github.com/bokeh/bokeh) library, which is used to
   generate interactive charts.
3. The Haskell [Hakyll](https://github.com/jaspervdj/hakyll) library,
   which is used to generate the site with documentation.

In order to generate the site in a given language (`en` and `sv` are currently
defined in the configuration file):

1. Run the
   [setupdb.sql](https://github.com/klpn/Mortchartgen.jl/blob/master/data/setupdb.sql)
   script in order to set up the database, e.g. `mysql
   --defaults-extra-file=tableimp.cnf < setupdb.sql`. The
   [tableimp.cnf](https://github.com/klpn/Mortchartgen.jl/blob/master/data/tableimp.cnf)
   file should be edited before the script is run, in order to suit your MySQL
   configuration.
2. Call the functions `download_who`, `table_import` and `wpp_convert` in
   [Download.jl](https://github.com/klpn/Mortchartgen.jl/blob/master/src/Download.jl).
   This downloads and imports the WHO data into a MySQL database, and also
   downloads data from the [UN World Population
   Projections](https://esa.un.org/unpd/wpp/), which is used to
   calculate mortality rates for some countries where population is lacking in
   WHO Mortality Database for recent years, and converts this data so that it
   can be merged with the population data frame created in the next step.
3. Save the frames with aggregated causes of death and population in CSV files, by calling
   `Mortchartgen.save_frames(cgen_frames())` in
   [Mortchartgen.jl](https://github.com/klpn/Mortchartgen.jl/blob/master/src/Mortchartgen.jl).
   Before this, you may have to edit the `conn_config` object in
   [chartgen.json](https://github.com/klpn/Mortchartgen.jl/blob/master/data/chartgen.json)
   to suit your MySQL settings.
   The saved frame can then be reloaded with `frames=Mortchartgen.load_frames()`.
4. Generate the site files by calling `writeplotsite` with loaded frames, language
   and output directory, e.g. `Mortchartgen.writeplotsite(frames, "en",
   normpath(Mortchartgen.mainpath, "mortchart-site-en"))`.
5. Compile the site generator from the `site.hs` file in the output directory.
   Using the Glasgow Haskell Compiler, you can run `ghc --make site` from the shell.
6. Generate the site itself by running `./site build` in the output directory.
   The site will be placed in the `_site` directory under the output directory.
