using Requests, ZipFile

datapath = normpath(Pkg.dir(), "Mortchartgen", "data")

dllist = ["documentation"; "availability"; "country_codes"; "notes"; "Pop";
	"morticd07"; "morticd08"; "morticd09"; "Morticd10_part1"; "Morticd10_part2"]

tablelist = ["MortIcd7"; "Morticd8"; "Morticd9"; "Morticd10_part1";
	"Morticd10_part2"; "pop"]

function download_who(dlpath = ".", filelist = dllist)
	preurl_def = "http://www.who.int/entity/healthinfo/statistics/"
	preurl_pop = "http://www.who.int/entity/healthinfo/"
	filesuff = ".zip"
	urlparams = Dict("ua" => "1")

	for filename in filelist
		filefullname = *(filename, filesuff)
		dlfilepath = normpath(dlpath, filefullname)
		if filename == "Pop"
			preurl = preurl_pop
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
	tablencnf = normpath(datapath, "tableimp.cnf"), filelist = tablelist)
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
end
