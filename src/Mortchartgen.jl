module Mortchartgen

using DataFrames, DataStructures, JSON, Loess, Mustache, MySQL, PyCall
@pyimport bokeh as bo
@pyimport bokeh.plotting as bp
@pyimport bokeh.palettes as bpal

mainpath = normpath(Pkg.dir(), "Mortchartgen")
datapath = normpath(mainpath, "data")
chartpath =  normpath(mainpath, "charts")
mkpath(chartpath)
conf = JSON.parsefile(normpath(datapath, "chartgen.json"),
	dicttype=DataStructures.OrderedDict)
tables = Dict(:deaths => "Deaths", :pop => "Pop")
dfarrmatch(col, arr) = map((x) -> in(x, arr), Vector(col))
ctrycodes = map((x)->parse(x), collect(keys(conf["countries"])))
perc_round(value) = replace("$(round(value, 4))", ".", ",")
dthalias(language) = ucfirst(conf["deaths"]["alias"][language])

function caalias(cause, language)
	if cause=="pop"
		return conf["pop"]["alias"][language]
	else
		return conf["causes"][cause]["alias"][language]
	end
end

function cgen_frames(causes = keys(conf["causes"]))
	conn_config = conf["settings"]["conn_config"]
	conn = mysql_connect(conn_config["host"], conn_config["user"],
		conn_config["password"], conn_config["database"],
		socket = conn_config["unix_socket"])
	qstr = *("select Sex,Year,Country,Admin1,",
		join(map((x)->"$(tables[:pop])$x,", 1:25)),
		"$(tables[:pop])26 from $(tables[:pop])")
	popframe = mysql_execute(conn, qstr)
	rename!(popframe,
		map((x)->Symbol("$(tables[:pop])$(x)"), 1:26),
		map((x)->Symbol("Age$(x)"), 1:26))
	dthframes = DataStructures.OrderedDict()
	for cause in causes
		causeexpr = conf["causes"][cause]["causeexpr"]
		selstat = *("Sex,Year,List,Country,Admin1,",
			join(map((x)->"$(tables[:deaths])$x,", 1:25)),
			"$(tables[:deaths])26")
		#Prepared statements give incorrect results.
		qstr = *("select ", selstat,
			" from $(tables[:deaths]) where ",
			"(case when List='07A' then Cause REGEXP '$(causeexpr["07A"])' ", 
			"when List='08A' then Cause REGEXP '$(causeexpr["08A"])' ",
			"when List REGEXP '09(B|N)' then Cause REGEXP '$(causeexpr["09B"])' ",
			"when List REGEXP '10(M|[3-4])' then Cause REGEXP '$(causeexpr["10"])' ", 
			"when List='101' then Cause REGEXP '$(causeexpr["101"])' end) ",
			"order by Year")
		dthframe = aggregate(mysql_execute(conn, qstr),
				[:Sex, :Year, :List, :Country, :Admin1], sum)
		rename!(dthframe,
			map((x)->Symbol("$(tables[:deaths])$(x)_sum"), 1:26),
			map((x)->Symbol("Age$(x)"), 1:26))
		dthframes[cause] = hcat(DataFrame(Cause = fill(cause, size(dthframe)[1])),
			dthframe)
	end
	mysql_disconnect(conn)
	frames = Dict(:deaths => vcat(values(dthframes)...), :pop => popframe)
	for tblkey in keys(tables)
		frame = frames[tblkey]
		for r in eachrow(frame)
			if r[:Country]==4100 && r[:Year]<1990
				r[:Country] = 4085
			elseif r[:Country]==3150 && r[:Year]>1974 && !isna(r[:Admin1])
				r[:Country] = 0
			end
		end
		delete!(frame, :Admin1)
		ncols = size(frame)[2]
		frame_trimmed = frame[dfarrmatch(frame[:Country], ctrycodes), :]
		frame_trimmed_long = stack(frame_trimmed, ncols-25:ncols)
		frames[tblkey] = frame_trimmed_long
	end
	frames
end

function save_frames(framedict)
	for tblkey in keys(tables)
		writetable(normpath(datapath, *(string(tblkey), ".csv")),
			framedict[tblkey])
	end
end

function load_frames()
	framedict = Dict()
	for tblkey in keys(tables)
		framedict[tblkey] = readtable(normpath(datapath, *(string(tblkey), ".csv")))
		framedict[tblkey][:variable] = map(Symbol, framedict[tblkey][:variable])
	end
	framedict
end

subframe_sray(df, sex, countries, agelist, years) = df[((df[:Sex].==sex)
	& (dfarrmatch(df[:Country], countries)) & (dfarrmatch(df[:variable], agelist))
	& (dfarrmatch(df[:Year], years))), :]
dfgrp_agemean(df, grpcol, f = mean) = by(df, grpcol, x -> DataFrame(value = f(x[:value])))
dfgrp_sum(df, grpcol, f = sum) = by(df, grpcol,
x -> DataFrame(value = f(x[:value]), value_1 = f(x[:value_1])))

function listchanges(country, years, framedict) 
	countryframe = subframe_sray(framedict[:deaths], 2, country, [:Age1], years)
	listframe = countryframe[countryframe[:Cause].=="all", [:Year; :List]]
	nrows = size(listframe)[1]
	lcomp = DataFrame(Year = listframe[:Year][2:nrows],
		List = listframe[:List][2:nrows], Listprev = listframe[:List][1:nrows-1])
	lcomp[lcomp[:List].!=lcomp[:Listprev], :]
end

function grpprop(numframe_sub, denomframe_sub, grpcol, agemean)
	numdenomframe_sub = join(numframe_sub, denomframe_sub, on = grpcol)
	if agemean
		propfr_agesp = DataFrame()
		propfr_agesp[grpcol] = numdenomframe_sub[grpcol]
		propfr_agesp[:value] = numdenomframe_sub[:value]./numdenomframe_sub[:value_1]
		return dfgrp_agemean(propfr_agesp, grpcol)
	else
		numdenomgrp = dfgrp_sum(numdenomframe_sub, grpcol)
		propfr_agegr = DataFrame()
		propfr_agegr[grpcol] = numdenomgrp[grpcol]
		propfr_agegr[:value] = numdenomgrp[:value]./numdenomgrp[:value_1]
		return propfr_agegr
	end
end

function propgrp(numframe, denomframe, sex, countries, agelist, years, agemean, grpcol)
	numframe_sub = subframe_sray(numframe, sex, countries, agelist, years)
	denomframe_sub = subframe_sray(denomframe, sex, countries, agelist, years)
	grpprop(numframe_sub, denomframe_sub, grpcol, agemean)
end

function ageslice(sage, eage, agemean, language)
	infsymb = "\u03c9"
	ages = map((x)->Symbol("Age$x"), 1:25)
	agest = [0;0:4;5:5:90;95]
	ageend = [infsymb;0:4;9:5:94;infsymb]
	if agemean
		agemeanstr = " $(conf["agemean"]["alias"][language])"
	else
		agemeanstr = ""
	end
	Dict(:agelist => ages[sage:eage],
		:alias => "$(agest[sage])\u2013$(ageend[eage])$agemeanstr",
		:color => bpal.Category20[20][mod1(sage, 20)])
end

function propplotframes(ca1, ca2, framedict, language)
	deaths = framedict[:deaths]
	ca1frame = deaths[deaths[:Cause].==ca1, :]
	ca1alias = caalias(ca1, language) 
	ca2alias = caalias(ca2, language) 
	if ca2=="pop"
		ca2frame = framedict[:pop]
	else
		ca2frame = deaths[deaths[:Cause].==ca2, :]
	end
	Dict(:ca1frame => ca1frame, :ca1alias => ca1alias,
		:ca2frame => ca2frame, :ca2alias => ca2alias)
end

function listlabels(country, years, minvals, framedict)
	lch = listchanges(country, years, framedict)
	lchdata = bo.models[:ColumnDataSource](data = Dict("year" => lch[:Year],
		"list" => lch[:List]))
	listlabels = bo.models[:LabelSet](x = "year", y = minimum(minvals), 
		text = "list", text_color = "red", angle = pi/2, render_mode = "canvas", 
		source = lchdata)
end

function propplot_sexesyrs(ca1, ca2, sexes, country, sage, eage, years, agemean,
	framedict, language, outfile, showplot)
	bp.reset_output()
	bp.output_file(outfile)
	ctryalias = conf["countries"][string(country)]["alias"][language]
	pframes = propplotframes(ca1, ca2, framedict, language)
	ages = ageslice(sage, eage, agemean, language)
	agealias = ages[:alias]
	agelist = ages[:agelist]
	figtitle = "$(dthalias(language)) $(pframes[:ca1alias])/$(pframes[:ca2alias]) $ctryalias"
	p = bp.figure(title = figtitle, y_axis_label = agealias,
		plot_width = 600, plot_height = 600)
	minvals = []
	for sex in sexes
		sexalias = conf["sexes"][string(sex)]["alias"][language]
		col = conf["sexes"][string(sex)]["color"]
		propframe = propgrp(pframes[:ca1frame], pframes[:ca2frame], 
			sex, country, agelist, years, agemean, :Year)
		yrfloatarr = convert(Array{Float64}, propframe[:Year])
		valarr = convert(Array, propframe[:value])
		propsm = Loess.predict(loess(yrfloatarr, valarr), yrfloatarr)
		p[:circle](propframe[:Year], propframe[:value], legend = sexalias, color = col)
		p[:line](propframe[:Year], propsm, legend = "$sexalias loess", color = col)
		minvals = vcat(minvals, minimum(propframe[:value]))
	end
	p[:add_layout](listlabels(country, years, minvals, framedict))
	p[:add_tools](bo.models[:CrosshairTool]())
	if showplot
		bp.show(p)
	else
		bp.save(p)
	end
end

function propplot_agesyrs(ca1, ca2, sex, country, agetuples, years, agemean,
	framedict, language, y_axis_type, outfile, showplot)
	bp.reset_output()
	bp.output_file(outfile)
	ctryalias = conf["countries"][string(country)]["alias"][language]
	pframes = propplotframes(ca1, ca2, framedict, language)
	sexalias = conf["sexes"][string(sex)]["alias"][language]
	figtitle = "$(dthalias(language)) $(pframes[:ca1alias])/$(pframes[:ca2alias]) $sexalias $ctryalias"
	p = bp.figure(title = figtitle, y_axis_type = y_axis_type,
		toolbar_location = "below", toolbar_sticky = false,
		plot_width = 600, plot_height = 600)
	agelegends = []
	minvals = []
	for agetuple in agetuples
		ages = ageslice(agetuple[1], agetuple[2], agemean, language)
		agealias = ages[:alias]
		agelist = ages[:agelist]
		propframe = propgrp(pframes[:ca1frame], pframes[:ca2frame], 
			sex, country, agelist, years, agemean, :Year)
		ageline = p[:line](propframe[:Year], propframe[:value], color = ages[:color])
		agelegends = vcat(agelegends, (agealias, [ageline]))
		minvals = vcat(minvals, minimum(propframe[:value]))
	end
	legend = bo.models[:Legend](items = agelegends, location = (0, -30))
	p[:add_layout](legend, "right")
	p[:add_layout](listlabels(country, years, minvals, framedict))
	if showplot
		bp.show(p)
	else
		bp.save(p)
	end
end

function propscat_yrsctry(ca1, ca2, sex, countries, sage, eage, year1, year2, agemean,
	framedict, language, outfile, showplot)
	bp.reset_output()
	bp.output_file(outfile)
	pframes = propplotframes(ca1, ca2, framedict, language)
	ages = ageslice(sage, eage, agemean, language)
	agealias = ages[:alias]
	agelist = ages[:agelist]
	sexalias =  conf["sexes"][string(sex)]["alias"][language]
	figtitle = "$(dthalias(language)) $(pframes[:ca1alias])/$(pframes[:ca2alias])\n$agealias $sexalias"
	yr1propframe = propgrp(pframes[:ca1frame], pframes[:ca2frame], sex,
		countries, agelist, year1, agemean, :Country)
	yr2propframe = propgrp(pframes[:ca1frame], pframes[:ca2frame], sex,
		countries, agelist, year2, agemean, :Country)
	propframe = join(yr1propframe, yr2propframe, on=:Country)
	isos = map((c)->conf["countries"][string(c)]["iso3166"], propframe[:Country])
	ctrynames = map((c)->conf["countries"][string(c)]["alias"][language], propframe[:Country])
	scatdata = bo.models[:ColumnDataSource](data = Dict("year1prop" => propframe[:value], 
		"year2prop" => propframe[:value_1], "isos" => isos, "ctrynames" => ctrynames))
	hover = bo.models[:HoverTool](tooltips =
			[("befolkning", "@ctrynames"),
			("$year1", "@year1prop"), 
			("$year2", "@year2prop")]) 
	p = bp.figure(title = figtitle, x_axis_label = "$year1",
		y_axis_label = "$year2", plot_width = 600, plot_height = 600)
	p[:add_tools](hover)
	p[:circle](x = "year1prop", y = "year2prop", size = 12, source = scatdata)
	isolabels = bo.models[:LabelSet](x = "year1prop", y = "year2prop", text = "isos",
		level = "glyph", x_offset = 5, y_offset = 5, source = scatdata)
	p[:add_layout](isolabels)
	if showplot
		bp.show(p)
	else
		bp.save(p)
	end
end

function propscat_sexesctry(ca1, ca2, countries, sage, eage, year, agemean,
	framedict, language, outfile, showplot)
	bp.reset_output()
	bp.output_file(outfile)
	pframes = propplotframes(ca1, ca2, framedict, language)
	ages = ageslice(sage, eage, agemean, language)
	agealias = ages[:alias]
	agelist = ages[:agelist]
	figtitle = "$(dthalias(language)) $(pframes[:ca1alias])/$(pframes[:ca2alias])\n$agealias $year"
	fempropframe = propgrp(pframes[:ca1frame], pframes[:ca2frame], 2,
		countries, agelist, year, agemean, :Country)
	malepropframe = propgrp(pframes[:ca1frame], pframes[:ca2frame], 1,
		countries, agelist, year, agemean, :Country)
	propframe = join(fempropframe, malepropframe, on=:Country)
	femalias =  conf["sexes"]["2"]["alias"][language]
	malealias = conf["sexes"]["1"]["alias"][language]
	isos = map((c)->conf["countries"][string(c)]["iso3166"], propframe[:Country])
	ctrynames = map((c)->conf["countries"][string(c)]["alias"][language], propframe[:Country])
	scatdata = bo.models[:ColumnDataSource](data = Dict("femprop" => propframe[:value], 
		"maleprop" => propframe[:value_1], "isos" => isos, "ctrynames" => ctrynames))
	hover = bo.models[:HoverTool](tooltips =
			[("befolkning", "@ctrynames"),
			("$femalias", "@femprop"), 
			("$malealias", "@maleprop")])
	p = bp.figure(title = figtitle, x_axis_label = femalias,
		y_axis_label = malealias, plot_width = 600, plot_height = 600)
	p[:add_tools](hover)
	p[:circle](x = "femprop", y = "maleprop", size = 12, source = scatdata)
	isolabels = bo.models[:LabelSet](x = "femprop", y = "maleprop", text = "isos",
		level = "glyph", x_offset = 5, y_offset = 5, source = scatdata)
	p[:add_layout](isolabels)
	if showplot
		bp.show(p)
	else
		bp.save(p)
	end
end

batchages_caflt(cause) = filter((age)-> 
	age["ca2"]!=cause &&
	((age["startage"]==1 && age["endage"]==1) ||
	(!(haskey(conf["causes"][cause], "lowerage")) ||
	age["endage"]>=conf["causes"][cause]["lowerage"]) && 
	(!(haskey(conf["causes"][cause], "upperage")) ||
	age["startage"]<=conf["causes"][cause]["upperage"])),
	conf["batchages"])

fname_sexesyrs(ca1, ca2, country, sage, eage, agemean) = 
*(ca1, ca2, country, "s", string(sage), "e", string(eage),
"mean", string(agemean), ".html")

agedict_bothsexes(sage, eage, agemean, language, ca2, fname) =
Dict("alias" => *(ageslice(sage, eage, agemean, language)[:alias],
	"/$(caalias(ca2, language))"),
	"fname" => fname)
agedict_sex(sage, eage, sex, agemean, language, ca2, fname) =
Dict("alias" => *(ageslice(sage, eage, agemean, language)[:alias],
	"/$(caalias(ca2, language)) ",
	conf["sexes"][string(sex)]["alias"][language]),
	"fname" => fname)

cadict(cause, children, language) = Dict("alias" => ucfirst(caalias(cause, language)),
"children" => children, "name" => cause)

function ctryints_flt(countries, year1, year2)
	countries_flt = filter((ctry)->conf["countries"][ctry]["startyear"]<=year1
				&& conf["countries"][ctry]["endyear"]>=year2, countries)
	map((c)->parse(c), countries_flt)
end

fname_yrsctry(ca1, ca2, sex, sage, eage, agemean, year1, year2) = 
 *(ca1, ca2, string(sex), "s", string(sage), "e", string(eage),
"mean", string(agemean), "ctries", string(year1), "vs", string(year2), ".html")

causes_flt_skipyrs(causes, year1, year2) =
filter((ca)-> !(haskey(conf["causes"][ca], "skipyrs")) || 
(!(year1 in conf["causes"][ca]["skipyrs"]) &&
!(year2 in conf["causes"][ca]["skipyrs"])),
causes)

fname_sexesctry(ca1, ca2, sage, eage, agemean, year) =
*(ca1, ca2, "s", string(sage), "e", string(eage), "mean", string(agemean),
"sexesctries", string(year), ".html")

function agebatchplot(framedict, age, plottype, language, ca1, child, countries, yr1, yr2, sexes)
	ca2 = age["ca2"]
	sage = age["startage"]
	eage = age["endage"]
	agemean = age["agemean"]
	if plottype == "sexesyrs"
		fname = fname_sexesyrs(ca1, ca2, child, sage, eage, agemean)
		outfile = normpath(chartpath, fname)
		propplot_sexesyrs(ca1, ca2, sexes, parse(child), 
			sage, eage, yr1:yr2,
			agemean, framedict, language, outfile, false)
		return agedict_bothsexes(sage, eage, agemean, language, ca2, fname)
	elseif plottype == "yrsctry"
		if ca1 in causes_flt_skipyrs(keys(conf["causes"]), yr1, yr2)
			agesexdicts = []
			ctryints = ctryints_flt(countries, yr1, yr2)
			for sex in sexes
				fname = fname_yrsctry(ca1, ca2, sex, sage, eage,
					agemean, yr1, yr2)
				outfile = normpath(chartpath, fname)
				propscat_yrsctry(ca1, ca2, sex, ctryints,
					sage, eage, yr1, yr2,
					agemean, framedict, language, outfile, false)
				agesexdict = agedict_sex(sage, eage, sex,
					agemean, language, ca2, fname)
				agesexdicts = vcat(agesexdicts, agesexdict)
			end
			return agesexdicts
		end
	elseif plottype == "sexesctry"
		if (ca1 in causes_flt_skipyrs(keys(conf["causes"]), yr1, yr2) &&
			conf["causes"][ca1]["sex"]==[2;1])
			ctryints = ctryints_flt(countries, yr1, yr2)
			year = yr1
			fname = fname_sexesctry(ca1, ca2, sage, eage, agemean, year)
			outfile = normpath(chartpath, fname)
			propscat_sexesctry(ca1, ca2, ctryints,
				sage, eage, year, agemean,
				framedict, language, outfile, false)
			return agedict_bothsexes(sage, eage, agemean, language, ca2, fname)
		end
	end
end

function batchplotalias(child, plottype, language)
	if plottype == "sexesyrs"
		return conf["countries"][child]["alias"][language]
	elseif plottype == "yrsctry"
		return "$(child[1]) vs $(child[2])"
	elseif plottype == "sexesctry"
		return "$child"
	end
end

function batchplotyrs(child, plottype)
	if plottype == "sexesyrs"
		return [conf["countries"][child]["startyear"];
			conf["countries"][child]["endyear"]]
	elseif plottype == "yrsctry"
		return child
	elseif plottype == "sexesctry"
		return [child; child]
	end
end

function childplot(framedict, language, plottype, ca1, countries, years, yrtups)
	ages = batchages_caflt(ca1)
	sexes = conf["causes"][ca1]["sex"]
	childdicts = []
	if plottype == "sexesyrs"
		children = countries
	elseif plottype == "yrsctry"
		children = yrtups
	elseif plottype == "sexesctry"
		children = years
	end
	for child in children
		print("$child\n")
		agedicts = []
		ages = batchages_caflt(ca1)
		yrs = batchplotyrs(child, plottype) 
		for age in ages
			agedict = agebatchplot(framedict, age, plottype, language, ca1, child,
				countries, yrs[1], yrs[2], sexes)
			agedicts = vcat(agedicts, agedict)
		end
		if !(agedicts[1]==nothing)
			childdict = Dict(
				"alias" => batchplotalias(child, plottype, language),
				"ages" => agedicts)
			childdicts = vcat(childdicts, childdict)
		end
	end
	childdicts
end

function batchplot(framedict, language, plottype, causes = collect(keys(conf["causes"])),
	countries = collect(keys(conf["countries"])), years = conf["batchsexesyrs"],
	yrtups = conf["batchyrtups"])
	sort!(causes, by=((c)->
		(conf["causes"][c]["causeclass"],
		!(conf["causes"][c]["classtot"]),
		conf["causes"][c]["alias"][language])))
	sort!(countries, by=((c)->conf["countries"][c]["alias"][language]))
	cadicts = []
	if plottype == "sexesctry"
		causes = filter((ca)->conf["causes"][ca]["sex"]==[2;1], causes)
	end
	for ca1 in causes
		print("$plottype, $ca1\n")
		children = childplot(framedict, language, plottype, ca1,
			countries, years, yrtups)
		cadicts = vcat(cadicts, cadict(ca1, children, language))
	end
	Dict(
		"plottype" => plottype,
		"cadicts" => cadicts
	)
end

function writeplotlist(batchplotdict, outfile)
	tpl = readstring(normpath(datapath, "plotlist.mustache"))
	write(outfile, render(tpl, batchplotdict))
end

function ccflt(causeclass, language)
	cavals = filter((c)->c["causeclass"]==causeclass, collect(values(conf["causes"])))
	cadicts = map((c)->Dict("alias" => ucfirst(c["alias"][language]), 
		"classtot" => c["classtot"], "codedesc" => c["codedesc"][language],
		"note" => c["note"][language]), cavals)
	sort!(cadicts, by=((c)->(!(c["classtot"]), c["alias"])))
end

function writetempl(language, fname, sitepath)
	haktemplpath = normpath(sitepath, "templates")
	mkpath(haktemplpath)
	tpl = readstring(normpath(datapath, "$fname.mustache"))
	maintempl = Dict()
	if (fname == "default" || fname == "site")
		maintempl["maintempldicts"] = map((p)->
			Dict("plottype" => p, "alias" => conf["plottypes"][p]["alias"][language]),
			keys(conf["plottypes"]))
		if fname == "default"
			outpath = haktemplpath
			ext = "html"
		elseif fname == "site"
			outpath = sitepath
			ext = "hs"
		end
	elseif (fname == "index" || fname == "mortchartdoc")
		if fname == "index"
			ext = "html"
		elseif fname == "mortchartdoc"
			ext = "md"
			maintempl["maintempldicts"] = map((cc)->
				Dict("class" => cc,
				"alias" => conf["causeclasses"][cc]["alias"][language],
				"causes" => ccflt(parse(cc), language)),
				keys(conf["causeclasses"]))
			maintempl["refhead"] = conf["refhead"][language]
		end
		outpath = sitepath
		maintempl["body"] = readstring(normpath(datapath, "$fname-$language.$ext"))
	end
	write(normpath(outpath, "$fname.$ext"), render(tpl, maintempl = maintempl))
end

function writeplotsite(framedict, language,
	sitepath = normpath(mainpath, "mortchart-site"))
	sitesubpaths = DataStructures.OrderedDict(
		"siteroot" => Dict("path" => "", "files" => 
			["default.csl"; "mortchartdoc_biber.bib"]),
		"css" => Dict("path" => "css", "files" => ["default.css"]),
		"images" => Dict("path" => "images", "files" => ["mortchartico.png"]),
		"charts" => Dict("path" => "charts", "files" => []))
	sitefullsubpaths = DataStructures.OrderedDict()
	for subpath in keys(sitesubpaths)
		sitefullsubpath = (normpath(sitepath, sitesubpaths[subpath]["path"]))
		sitefullsubpaths[subpath] = sitefullsubpath
		mkpath(sitefullsubpath)
		for file in sitesubpaths[subpath]["files"]
			cp(normpath(datapath, file), normpath(sitefullsubpath, file),
				remove_destination = true)
		end
	end
	for plottype in keys(conf["plottypes"])
		batchplotdict = batchplot(framedict, language, plottype)
		writeplotlist(batchplotdict, normpath(sitepath, "$plottype.html"))
	end
	chartdestpath = sitefullsubpaths["charts"]
	for chartfile in readdir(chartpath)
		mv(normpath(chartpath, chartfile), normpath(chartdestpath, chartfile),
		remove_destination = true)
	end
	for fname in ["default"; "index"; "site"; "mortchartdoc"]
		writetempl(language, fname, sitepath)
	end
end

end # module
