***** Staggered Treatment Effects

clear
set obs 10000

set seed 2742

*--------------------------------------------------------*
* Create dataset
*--------------------------------------------------------*

**Gen id and year
egen year=seq(), f(2000) t(2010)

gen temp=_n if year==2000

carryforward temp, gen(id)
drop temp

** gen random cohort
gen random_num = runiform()
bysort id (random_num): gen random_year = year[_n==1]

bys id: egen cohort=max(random_year)

drop random_num random_year

** gen random treatment 
sort id
gen random_num = runiform()
gen temp=random_num if year==cohort
carryforward temp, replace
gen treat= temp > 0.3

**gen never treated 
replace cohort=. if treat==0

**Gen event time
sort id year
gen event_time= year-cohort

*Balance event_time
keep if inrange(event_time, -8,8) | event_time==.

** replace because stata do not admit negative values for event time
su event_time

*balance event time 
gen event_time_pos=event_time+`r(max)'


*--------------------------------------------------------*
* Variables 
*--------------------------------------------------------*

** gen outcome 
gen outcome = runiform() * 100

**add some treat effect
replace outcome = outcome + 10 if treat == 1 & event_time>=0

*--------------------------------------------------------*
* OLS Regression
*--------------------------------------------------------*

*** Note event time positive 9 correspond to -1

***WITHOU NEVER TREATED

*** Note that in this regression stata omits one event time: this is because year fe and event time are collinear
reghdfe outcome ib7.event_time_pos, a(year id) vce(robust)

***Adjust collinearity as per Borusjak: must bin, e.g. first event period
gen event_time_adj=event_time_pos
replace event_time_adj=1 if event_time_pos==0

reghdfe outcome ib7.event_time_adj, a(year id) vce(robust)

***Notice that we are not using never treated so the estimates only use the treatment as reference: add never treated at -1 

***WITH NEVER TREATED: not needed to bin the data

*Define never treated
replace event_time_pos=7 if cohort==.
tab event_time_pos

reghdfe outcome ib7.event_time_pos, a(year id) vce(robust)

*This is a classical staggered event study. Note that the interaction is not needed because all the information is in the event time variable. 

*--------------------------------------------------------*
* Sun and Abraham: eventstudyinteract
*--------------------------------------------------------*

*ssc install eventstudyinteract
help eventstudyinteract

*Create event time in SA format. Exclude -1 manually as reference

*identify never treated 
gen never_treat=(cohort==.)

*negative event time
forvalues k = 8(-1)2 {
           gen g_`k' = event_time == -`k' 
        }
		

*positive event time
forvalues k = 0/8 {
             gen g`k' = event_time == `k' 
        }
	
*Run
eventstudyinteract outcome g_* g0-g8, absorb(year id) cohort(cohort) control_cohort(never_treat) vce(robust)

*--------------------------------------------------------*
* Callaway and Sant'Anna: csdid
*--------------------------------------------------------*

*ssc install csdid
*requires also: ssc install drdid
help  csdid

*CSdid wants to specify never treated in cohort variable
gen cs_cohort=cohort 
replace cs_cohort=0 if cohort==.

*option is agg() = aggregation of ATT. Default is ATTg, i.e. by cohort
csdid outcome, ivar(id) time(year) gvar(cs_cohort) 

*simple att=agg(simple)
csdid outcome, ivar(id) time(year) gvar(cs_cohort) agg(event)

*Note that CS did automatically excludes the endpoints assuming 0 treatment 
*effect in those periods

*--------------------------------------------------------*
* Borusyak: did_imputation
*--------------------------------------------------------*

*ssc install did_imputation

*never treated set to missing 

*pretrends() n of pretrends -1 as a reference
did_imputation outcome id year cohort, allhorizons autosample pretrends(7) 

