#the function extract SNPs ids, genotypes from vcf file
#the genetic locations are generated by passing the output of "physical2genomic" function
get_parental_genotypes <- function(input,gen2phy,keep_homo)
{
	require(Rcpp)
	file = file(input, "r")
	if (gsub('#.*','',readLines(input,n=1))=='rs')
	{
	    isvcf = FALSE
	}else
	{
	    isvcf = TRUE
	}
	close(file)
	#checking if the file is vcf or hapmap
	if (isvcf == FALSE)
	{
	    a1 = read.table(input,comment.char="",header=TRUE,check.names=FALSE)
		ids = paste0(a1[,3],"_",a1[,4])
		h2 = colnames(a1)[12:length(colnames(a1))]
	}else
	{
	    a1 = read.table(input)
		ids = paste0(a1[,1],"_",a1[,2])
		file = file(input, "r")
		while (TRUE) 
		{
			line = readLines(file, n = 1)
			h1 = strsplit(line[1], '\\t')
			if (h1[[1]][1] == "#CHROM")
			{
			  break
			}
		}
		close(file)
		h1 = strsplit(line, '\\t')[[1]]
		h2 = h1[10:length(h1)]
	}
	if(!missing(gen2phy))
	{
	    if(is.list(gen2phy))
	    {
	        if (isvcf == FALSE)
	        {
	            a1 = a1[which(as.character(a1[,3]) %in% names(gen2phy)),]
                ids = paste0(a1[,3],"_",a1[,4])
	        }else
	        {
	            a1 = a1[which(as.character(a1[,1]) %in% names(gen2phy)),]
                ids = paste0(a1[,1],"_",a1[,2])
	        }
	    }
	}
	if (missing(input))
	{
		stop('You have to specify an input vcf or hapmap file')
	}
	all = TRUE
	if(missing(keep_homo))
	{
		HOMO = TRUE
	}else
	{
		HOMO = keep_homo
	}	
	##reading and reformating the input file#####################################################
	cppFunction('CharacterMatrix fun1(CharacterMatrix input,bool homo,bool vcf) {
	int X = input.nrow();
	int Y;
	if(vcf==true)
	{
		Y = input.ncol()-9;
	}
	else
	{
		Y = input.ncol()-11;
	}
	CharacterMatrix output(X,Y);
	int redunt;
	std::string previous;
	//SRcpp::Rcout  << Y << std::endl << X << std::endl;
	for (int x =0; x<X;x++)
	{
	redunt = 0;
		for (int y =0; y<Y; y++)
		{
			std::string s1,s1a,s1b;
			if(vcf==true)
			{
				
				s1 = (Rcpp::as<std::string>(input(x,y+9))).substr(0,3);
				//Rcpp::Rcout << s1 << std::endl;
				if(s1=="0/0")
				{
					output(x,y) = Rcpp::as<std::string>(input(x,3))+Rcpp::as<std::string>(input(x,3));
				}
				else if (s1=="1/1")
				{
					output(x,y) = Rcpp::as<std::string>(input(x,4))+Rcpp::as<std::string>(input(x,4));
				}
				else if (s1=="1/0" || s1=="0/1")
				{
					if(homo == true)
					{
						output(x,y) = "hetero";
					}
					else
					{
						output(x,y) = Rcpp::as<std::string>(input(x,3))+Rcpp::as<std::string>(input(x,4));
					}
				}
				else
				{
					output(x,y) = Rcpp::as<std::string>(input(x,3))+Rcpp::as<std::string>(input(x,3));
				}
				if((Rcpp::as<std::string>(input(x,3))).length() > 1 || (Rcpp::as<std::string>(input(x,4))).length() > 1)
				{
				    output(x,y) = "INDEL";
				}
			}
			else
			{
				s1 = Rcpp::as<std::string>(input(x,y+11));
				s1a = s1.substr(0,1);
				s1b = s1.substr(1,1);
				if(s1a != s1b && homo == true)
				{
					output(x,y) = "hetero";
				}
				else
				{
					output(x,y) = s1;
				}
			}
				
    if(output(x,y)!=previous && y>0)
    {
	    redunt=redunt+1;
    }				
    previous = output(x,y);		

		    }
    if(redunt==0)
    {
	    output(x,Y-1) = "redundant";
    }
    redunt = 0;
	}
	return output;
	}')
	
	if(!missing(gen2phy) && is.list(gen2phy))
	{
	    A1 = fun1(as.matrix(a1),HOMO,isvcf)
	    colnames(A1) = h2
	    rownames(A1) = ids
	    A2 = A1[!apply(A1, 1, function(x){any(x=="redundant")}),]
	    A3 = A2[!apply(A2, 1, function(x){any(x=="hetero")}),]
	    A3 = A3[!apply(A3, 1, function(x){any(x=="INDEL")}),]
	}else
	{
        A3 = a1[,12:ncol(a1)]
        rownames(A3) = paste0(a1[,3],"_",a1[,4])
	}
	### getting the genomic locations
	cppFunction('NumericVector gloci(List l1,NumericVector x){
    Rcpp::Environment base("package:stats"); 
    Rcpp::Function estimate = base["predict"];
    NumericVector a;
    a = estimate(Rcpp::_["object"] = l1,Rcpp::_["newdata"] = x);
    return(a);
    }')

	if(!missing(gen2phy))
	{
	    if(is.list(gen2phy))
	    {
			C1 = gsub('_.*$','',rownames(A3))
			C2 =  gsub('^.*_','',rownames(A3))
			C3 = data.frame(C1,C2)
			C5 = data.frame()
			count1= 1
			count2= 0
	        for (x in names(gen2phy))
	        {
				C4 = C3[C3$C1 %in% x,]
				if(nrow(C4) == 0){next}
		        a = gloci(gen2phy[[x]]$smooth,as.numeric(as.character(C4$C2)))
				count2 = count2 + (length(a))
		        C5[count1:count2,1] = paste0(C4$C1,"_",C4$C2)
				C5[count1:count2,2] = a
				count1 = count2 +1
	        }
	        C6 = C5[!is.na(C5$V2),]
	        C7 = as.data.frame(C6[,2])
	        colnames(C7) = "loci"
	        rownames(C7) = as.character(C6[,1])
	        A3 = A3[which(rownames(A3) %in% as.character(C6[,1])),]
	        return(list(genotypes = A3, gen2phy = C7))
	    }else if(is.character(gen2phy))
	    {
	        B1 = read.table(gen2phy)
            V1 = paste0(B1$V1,'_',B1$V2)
            V2 = B1$V3
            B2 = data.frame(V2)
            colnames(B2) = "loci"
            rownames(B2) = V1    
			A3 = A3[rownames(A3) %in% V1,]
			return(list(genotypes = as.matrix(A3), gen2phy = B2))
	    }
    }else
    {
        return(list(genotypes = A3))
    }
}

