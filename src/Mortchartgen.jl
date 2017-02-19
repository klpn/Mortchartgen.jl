module Mortchartgen

using DataFrames, DataStructures, JSON, MySQL, PyCall
@pyimport bokeh as bo
@pyimport bokeh.plotting as bp
@pyimport bokeh.palettes as bpal

datapath = normpath(Pkg.dir(), "Mortchartgen", "data")
conf = JSON.parsefile(normpath(datapath, "chartgen.json"),
	dicttype=DataStructures.OrderedDict)
tables = Dict(:deaths => "Deaths", :pop => "Pop")
dfarrmatch(col, arr) = map((x) -> in(x, arr), Vector(col))
ctrycodes = map((x)->parse(x), collect(keys(conf["countries"])))
perc_round(value) = replace("$(round(value, 4))", ".", ",")

function cgen_frames(causekeys = keys(conf["causes"]))
	causes = filter((k, v) -> k in causekeys, conf["causes"])
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
	for causekey in causekeys
		causeexpr = causes[causekey]["causeexpr"]
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
		dthframes[causekey] = hcat(DataFrame(Cause = fill(causekey, size(dthframe)[1])),
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
dfgrp(df, grpcol, f = sum) = by(df, grpcol, x -> DataFrame(value = f(x[:value])))

function grpprop(numframe_sub, denomframe_sub, grpcol, agemean)
	if agemean
		propfr_agesp = DataFrame()
		propfr_agesp[grpcol] = numframe_sub[grpcol]
		propfr_agesp[:value] = numframe_sub[:value]./denomframe_sub[:value]
		return dfgrp(propfr_agesp, grpcol, mean)
	else
		numgrp = dfgrp(numframe_sub, grpcol)
		denomgrp = dfgrp(denomframe_sub, grpcol)
		propfr_agegr = DataFrame()
		propfr_agegr[grpcol] = numgrp[grpcol]
		propfr_agegr[:value] = numgrp[:value]./denomgrp[:value]
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
	ca1alias = conf["causes"][ca1]["alias"][language]
	if ca2=="pop"
		ca2frame = framedict[:pop]
		ca2alias = conf["pop"]["alias"][language]
		
	else
		ca2frame = deaths[deaths[:Cause].==ca2, :]
		ca2alias = conf["causes"][ca2]["alias"][language]
	end
	Dict(:ca1frame => ca1frame, :ca1alias => ca1alias,
		:ca2frame => ca2frame, :ca2alias => ca2alias)
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
	figtitle = "Döda $(pframes[:ca1alias])/$(pframes[:ca2alias]) $ctryalias"
	p = bp.figure(title = figtitle, y_axis_label = agealias)
	for sex in sexes
		sexalias = conf["sexes"][string(sex)]["alias"][language]
		col = conf["sexes"][string(sex)]["color"]
		propframe = propgrp(pframes[:ca1frame], pframes[:ca2frame], 
			sex, country, agelist, years, agemean, :Year)
		p[:line](propframe[:Year], propframe[:value], legend = sexalias, color = col)
	end
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
	figtitle = "Döda $(pframes[:ca1alias])/$(pframes[:ca2alias]) $sexalias $ctryalias"
	p = bp.figure(title = figtitle, y_axis_type = y_axis_type,
		toolbar_location = "below", toolbar_sticky = false)
	agelegends = []
	for agetuple in agetuples
		ages = ageslice(agetuple[1], agetuple[2], agemean, language)
		agealias = ages[:alias]
		agelist = ages[:agelist]
		propframe = propgrp(pframes[:ca1frame], pframes[:ca2frame], 
			sex, country, agelist, years, agemean, :Year)
		ageline = p[:line](propframe[:Year], propframe[:value], color = ages[:color])
		agelegends = vcat(agelegends, (agealias, [ageline]))
	end
	legend = bo.models[:Legend](items = agelegends, location = (0, -30))
	p[:add_layout](legend, "right")
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
	figtitle = "Döda $(pframes[:ca1alias])/$(pframes[:ca2alias])\n$agealias $year"
	fempropframe = propgrp(pframes[:ca1frame], pframes[:ca2frame], 2,
		countries, agelist, year, agemean, :Country)
	malepropframe = propgrp(pframes[:ca1frame], pframes[:ca2frame], 1,
		countries, agelist, year, agemean, :Country)
	femalias =  conf["sexes"]["2"]["alias"][language]
	malealias = conf["sexes"]["1"]["alias"][language]
	isos = map((c)->conf["countries"][string(c)]["iso3166"], fempropframe[:Country])
	ctrynames = map((c)->conf["countries"][string(c)]["alias"][language], fempropframe[:Country])
	scatdata = bo.models[:ColumnDataSource](data = Dict("femprop" => fempropframe[:value], 
		"maleprop" => malepropframe[:value], "isos" => isos, "ctrynames" => ctrynames))
	hover = bo.models[:HoverTool](tooltips =
			[("befolkning", "@ctrynames"),
			("$femalias", "@femprop"), 
			("$malealias", "@maleprop")])
	p = bp.figure(title = figtitle, x_axis_label = femalias,
		y_axis_label = malealias)
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

end # module
