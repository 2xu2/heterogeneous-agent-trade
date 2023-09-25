include("ha-trade.jl")
using MINPACK
using Plots
using CSV
using DataFrames
using StatsBase

####################################################################################
####################################################################################
# This sets up the EK trade data and gravity stuff

dftrade = DataFrame(CSV.File("../../ek-data/ek-data.csv"))

dftrade.trade = parse.(Float64, dftrade.trade)
    # forsome reason, now it reads in as a "String7"
    
dflang = DataFrame(CSV.File("../../ek-data/ek-language.csv"))
    
dflabor = DataFrame(CSV.File("../../ek-data/ek-labor.csv"))
    
filter!(row -> ~(row.trade ≈ 1.0), dftrade);
    
filter!(row -> ~(row.trade ≈ 0.0), dftrade);
    
dftrade = hcat(dftrade, dflang);
    
    #dfcntryfix = select(dftrade,Not("trade"))
dfcntryfix = DataFrame(CSV.File("../../ek-data/ek-cntryfix.csv"))
    # these are the fixed characteristics of each country...


trade_cost_type = "ek"

grvdata = gravity(dftrade, display = true, trade_cost_type = trade_cost_type );

trc = trade_costs(grvdata.dist_coef, grvdata.lang_coef, grvdata.θm)

grv_params = gravity_params(L = dflabor.L, dfcntryfix = dfcntryfix, Ncntry = 19)

####################################################################################
#################################################################################

L = dflabor.L

Ncntry = size(L)[1]

γ = 1.45
σϵ = 0.33
ψslope = 0.0

hh_prm = household_params(Ncntry = Ncntry, Na = 100, β = 0.92,
γ = γ, ϕ = 0.5, amax = 8.0, σϵ = σϵ, ψslope = ψslope)

cntry_prm = country_params(Ncntry = Ncntry, L = L)

R = 1.01

dfparams = DataFrame(CSV.File("./calibration-files/current-guess-no-quality.csv"))


dfWguess = DataFrame(CSV.File("./calibration-files/current-wage-no-quality.csv"))


initial_x = [dfWguess.guess[1:19]; dfparams.guess[1:end]]
# last one in the W guess is the discount factor

out = calibrate_world_equillibrium(initial_x, R, grvdata, grv_params, hh_prm, 
                                cntry_prm, trade_cost_type = trade_cost_type)


f(x) = calibrate_world_equillibrium(x, R, grvdata, grv_params, hh_prm, 
                cntry_prm, trade_cost_type = trade_cost_type)

function f!(fvec, x)

    fvec .= f(x)

end

n = length(initial_x)

diag_adjust = 19

sol = fsolve(f!, initial_x, show_trace = true, method = :hybr;
      ml=diag_adjust, mu=diag_adjust,
      diag=ones(n),
      mode= 1,
      tol=1e-5,)



dfguess = DataFrame(guess = sol.x[20:end]);
CSV.write("./calibration-files/current-guess-no-quality.csv", dfguess)

dfWRguess = DataFrame(guess = sol.x[1:19]);
CSV.write("./calibration-files/current-wage-no-quality.csv", dfWRguess)



