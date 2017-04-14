using Requests, ZipFile, DataFrames

datapath = normpath(Pkg.dir(), "Mortchartgen", "data")

dllist = ["documentation"; "availability"; "country_codes"; "notes"; "Pop";
	"morticd07"; "morticd08"; "morticd09"; "Morticd10_part1"; "Morticd10_part2";
	"WPP2015_DB04_Population_By_Age_Annual"]

tablelist = ["MortIcd7"; "Morticd8"; "Morticd9"; "Morticd10_part1";
	"Morticd10_part2"; "pop"]

function download_who(dlpath = ".", filelist = dllist)
	preurl_def = "http://www.who.int/entity/healthinfo/statistics/"
	preurl_pop = "http://www.who.int/entity/healthinfo/"
	preurl_wpp = "https://esa.un.org/unpd/wpp/DVD/Files/1_Indicators%20(Standard)/ASCII_FILES/"
	filesuff = ".zip"
	urlparams = Dict("ua" => "1")
	wppfile = dllist[end]

	for filename in filelist
		filefullname = *(filename, filesuff)
		dlfilepath = normpath(dlpath, filefullname)
		if filename == "Pop"
			preurl = preurl_pop
		elseif filename == wppfile
			preurl = preurl_wpp
		else
			preurl = preurl_def
		end
		url = *(preurl, filefullname)
		print("$url\n$dlfilepath\n")
		Requests.save(Requests.get(url; query = urlparams), dlfilepath)
		r = ZipFile.Reader(dlfilepath)
		for f in r.files
			write(normpath(dlpath, f.name), read(f))
		end
		close(r)
	end
end

function table_import(dlpath = ".", 
	tablecnf = normpath(datapath, "tableimp.cnf"), filelist = tablelist)
	for filename in tablelist
		dlfilepath = normpath(dlpath, filename)
		if filename == "pop"
			temppath = normpath(dlpath, "Pop")
		else
			temppath = normpath(dlpath, "Deaths")
		end
		mv(dlfilepath, temppath)
		run(`mysqlimport --defaults-extra-file=$tablecnf
			Morticd $temppath`)
		mv(temppath, dlfilepath)
	end
	cp(normpath(dlpath, "country_codes"), normpath(datapath, "country_codes"),
		remove_destination = true)
end

function wpp_convert(dlpath = ".", syr = 1990, eyr = 2015)
	addages = map((x,y)->Symbol("Pop_$(x)_$(y)"), 5:5:95, [9:5:94;100])
	inclages = map((x,y)->Symbol("Pop_$(x)_$(y)"), [0;0:5:95], [100;4:5:94;100])
	whoages = map((x)->Symbol("Age$x"), [1;2;7:25])
	dropcols = [:LocID; :Location; :VarID; :Variant; :MidPeriod; :Sex; :Pop_80_100; :Pop_95_99; :Pop_100]
	country_codes = readtable(normpath(datapath, "country_codes"))
	rename!(country_codes, [:country; :name], [:Country; :Location])
	wpp = readtable(normpath(dlpath, "WPP2015_DB04_Population_By_Age_Annual.csv"))
	wpp = wpp[((wpp[:SexID].<3) & (wpp[:Time].>=syr) & (wpp[:Time].<=eyr)), :]
	wpp = join(wpp, country_codes, on = :Location)
	wpp[:Pop_95_100] = wpp[:Pop_95_99] .+ wpp[:Pop_100]
	wpp[:Pop_0_100] = wpp[:Pop_0_4]

	for age in addages
		wpp[:Pop_0_100] = wpp[:Pop_0_100] .+ wpp[age]
	end

	delete!(wpp, dropcols)
	rename!(wpp, inclages, whoages)

	wpp_long = stack(wpp, whoages)
	wpp_long = DataFrame(variable = wpp_long[:variable], value = wpp_long[:value] .* 1000,
		Sex = wpp_long[:SexID], Year = wpp_long[:Time], Country = wpp_long[:Country])
	writetable(normpath(datapath, "wppconverted.csv"), wpp_long)
end
