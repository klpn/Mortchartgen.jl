using Requests, ZipFile, DataFrames

datapath = normpath(Pkg.dir(), "Mortchartgen", "data")

dllist = ["documentation"; "availability"; "country_codes"; "notes"; "Pop";
	"morticd07"; "morticd08"; "morticd09"; "Morticd10_part1"; "Morticd10_part2";
	"WPP2017_PopulationByAgeSex_Medium"]

tablelist = ["MortIcd7"; "Morticd8"; "Morticd9"; "Morticd10_part1";
	"Morticd10_part2"; "pop"]

whosuff = ".zip"
wppsuff = ".csv"

function download_who(dlpath = ".", filelist = dllist)
	preurl_def = "http://www.who.int/entity/healthinfo/statistics/"
	preurl_pop = "http://www.who.int/entity/healthinfo/"
	preurl_wpp = "https://esa.un.org/unpd/wpp/DVD/Files/1_Indicators%20(Standard)/CSV_FILES/"
	urlparams = Dict("ua" => "1")
	wppfile = dllist[end]

	for filename in filelist
		if filename == "Pop"
			preurl = preurl_pop
			filesuff = whosuff
		elseif filename == wppfile
			preurl = preurl_wpp
			filesuff = wppsuff
		else
			preurl = preurl_def
			filesuff = whosuff
		end
		filefullname = *(filename, filesuff)
		dlfilepath = normpath(dlpath, filefullname)
		url = *(preurl, filefullname)
		print("$url\n$dlfilepath\n")
		Requests.save(Requests.get(url; query = urlparams), dlfilepath)
		if filesuff == ".zip"
			r = ZipFile.Reader(dlfilepath)
			for f in r.files
				write(normpath(dlpath, f.name), read(f))
			end
			close(r)
		end
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

function wpp_convert(dlpath = ".", syr = 1990, eyr = 2016)
	whoages = map((x)->Symbol("Age$x"), [7:25;25])
	wppages = [map((x,y)->"$(x)-$(y)", 5:5:95, 9:5:99); "100+"]
	ages = DataFrame(variable = whoages, AgeGrp = wppages)
	country_codes = readtable(normpath(datapath, "country_codes"))
	rename!(country_codes, [:country; :name], [:Country; :Location])
	wpp = readtable(normpath(dlpath, *(dllist[end], wppsuff)))
	wpp = wpp[((wpp[:Time].>=syr) .& (wpp[:Time].<=eyr)), :]
	wpp = join(wpp, country_codes, on = :Location)
	wpp = join(wpp, ages, on = :AgeGrp)
	wppsexes = Dict()
	for (i, sexcol) in enumerate([:PopMale, :PopFemale])
		wppsexes[i] = DataFrame(variable = wpp[:variable], value = wpp[sexcol] .* 1000,
			Sex = i, Year = wpp[:Time], Country = wpp[:Country])
	end
	wpp = aggregate(vcat(values(wppsexes)...), [:variable; :Year; :Sex; :Country], sum)
	wpp = DataFrame(variable = wpp[:variable], value = wpp[:value_sum], Sex = wpp[:Sex],
		Year = wpp[:Year], Country = wpp[:Country])
	sort!(wpp, cols = [order(:variable, by = (x)->parse("$x"[4:end])); :Country; :Year; :Sex])
	writetable(normpath(datapath, "wppconverted.csv"), wpp)
end
