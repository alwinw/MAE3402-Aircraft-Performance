#----------------------------
#--- Functions for Calculation
#============================

## General ======================================================================
# K
K <- function(AR, e)
  1 / (pi * AR * e)
# Free stream velocity give Mach number and speed of sound
Vinf <- function(mach, a)
  mach * a
# Bernoulli value given free stream velocity and air density
qinf <- function(rho, Vinf)
  1 / 2 * rho * Vinf ^ 2
# Coefficient of lift at Vinf
Cl <- function(W, qinf, S)
  W / (qinf * S)
# Coefficient of drag from Cd0, K, Cl
Cd <- function(Cd0, K, Cl)
  Cd0 + K * Cl ^ 2
# Lift Force
L <- function(qinf, S, Cl)
  qinf * S * Cl
# Draf Force
D <- function(qinf, S, Cd)
  qinf * S * Cd
# Lift on Drag
ClCd <- function(L, D)
  L / D
# Stall
Vmin <- function(rho, W, S, Clmax)
  sqrt(2 / rho * W / S * 1 / Clmax)

## Thrust ======================================================================
#---Thrust i.e. minimum thrust for (L/D)max
#---for prop, this gives the best range
#---for jet, this gives the best endurance
# Cl*
Clstar <- function(Cd0, K)
  sqrt(Cd0 / K)
# Cd*
Cdstar <- function(Cd0)
  2 * Cd0
# (L/D)*
ClCdstar <- function(Cd0, K)
  1 / sqrt(4 * Cd0 * K)
# V*
Vstar <-
  function(rho, W, S, K, Cd0)
    sqrt(2 / rho * W / S) * (K / Cd0) ^ 0.25
# u, dimensionless airspeed
U <- function(Vinf, Vstar)
  Vinf / Vstar

## Power ======================================================================
#---Power i.e. minimum thrust for (L^(3/2)/D)max
#---for prop, this gives the best endurance
# Cl
Cl32 <- function(Clstar)
  sqrt(3) * Clstar
# Cd
Cd32 <- function(Cdstar)
  2 * Cdstar # Double Check
# (L/D)
ClCd32 <- function(ClCdstar)
  sqrt(3 / 4) * ClCdstar
# V
V32 <- function(Vstar)
  (1 / 3) ^ (1 / 4) * Vstar

## Power Required ======================================================================
# Minimum power i.e. (L^(3/2)/D)max @ V32 but this does NOT maximise range!!
PRmin <-
  function(rho, W, S, Cd0, K)
    (256 / 27) ^ 0.25 * (2 / rho * W / S) ^ 0.5 * (Cd0 * K ^ 3) ^ 0.25 * W
# Power required @ any airspeed
PR <- function(Vinf, rho, W, S, Cd0, K) {
  W * sqrt(2 / rho * W / S *
             (Cd0 + K * (2 / rho * W / S * 1 / (Vinf ^ 2)) ^ 2) ^ 2 /
             ((2 / rho * W / S * 1 / (Vinf ^ 2)) ^ 3))
}

## Thrust Required ======================================================================
TRmin <- function(W, ClCdstar)
  W / ClCdstar
TR <- function(W, ClCd)
  W / ClCd

## Altitude Effect ======================================================================
#--- Altitude Effect (TO DOUBLE CHECK!!)
# Altitude constants
alt_r = 0.5
alt_s = 0.7
# Power Available
PA <- function(sigma, P0)
  sigma ^ 0.7 * P0
# Excess Power
Pexc <- function(PA, PR)
  PA - PR
# Thrust Available
TA <- function(PA, Vinf)
  PA / Vinf
# Excess Thrust
Texc <- function(TA, TR)
  TA - TR

## Maximum speed @ altitude ======================================================================
VmaxP <- function(PA, rho, W, S, Cd0, K, x1, x2, info = FALSE) {
  SecantRootUnivariate(function(Vinf)
    PA - PR(Vinf, rho, W, S, Cd0, K), x1, x2, info)
}

## Weight Estimate  ======================================================================
# Dimensional constants
RaymerClass <-
  data.frame(
    name = c("General Aviation - twin engine", "Twin Turboprop"),
    A = c(1.4, 0.92),
    C = c(-0.10, -0.05)
  )

# Raymer's Equivalent curve fits for We/W0
RaymerFit <- function(W0, type) {
  coef <- RaymerClass %>% filter_(interp(quote(name == x), x = type))
  return(coef$A * W0 ^ coef$C)
}
BatteryFrac <-function(R, g, E, eta, ClCd)
    (R * g) / (E * eta * ClCd)
PayloadFrac <- function(Wpp, W0)
  Wpp / W0


## AeroParams Dataframe Operation  ======================================================================
AeroParams <- function(inputvals) {
  out <- data.frame(sapply(inputvals, rep.int, times = 3))
  out$type <- c("Sea Level", "Cruise", "Climb")
  out$h <- c(0, h_cruise, h_ceil)
  out <- StandardAtomsphere(out)
  out <- out %>%
    mutate(
    M = M,
    Vinf = M * a,
    qinf = qinf(rho, Vinf),
    Cl = Cl(W, qinf, S),
    Cd = Cd(Cd0, K, Cl),
    ClCd = ClCd(Cl, Cd),
    Clstar = Clstar(Cd0, K),
    Cdstar = Cdstar(Cd0),
    ClCdstar = ClCdstar(Cd0, K),
    Vstar = Vstar(rho, W, S, K, Cd0),
    Cl32 = Cl32(Clstar),
    Cd32 = Cd32(Cdstar),
    ClCd32 = ClCd32(ClCdstar),
    V32 = (Vstar)
    )
}

## ThrustPowerCurves Dataframe Operation  ======================================================================
ThrustPowerCurves <- function(input, minh, maxh, nh, minv, maxv, nv, VmaxP1, VmaxP2) {
  out <- 
    data.frame(h = rep(seq(minh, maxh, length.out = nh), each = nv),
               Vinf = rep(seq(minv, maxv, length.out = nv), times = nh))
  out <- out %>%
    mutate(
      W = input$W,
      S = input$S,
      Cd0 = input$Cd0,
      P0 = input$P0,
      Clmax = input$Clmax
    ) 
  out$K = input$K 
  out <- out %>%
    StandardAtomsphere(.) %>%
    group_by(h) %>%
    mutate(
      qinf = qinf(rho, Vinf),
      Cl = Cl(W, qinf, S),
      Cd = Cd(Cd0, K, Cl),
      ClCd = ClCd(Cl, Cd),
      ClCdstar = ClCdstar(Cd0, K),
      Vmin = Vmin(rho, W, S, Clmax),
      Vstar = Vstar(rho, W, S, K, Cd0),
      V32 = V32(Vstar),
      Vcruise = M*a,
      PRmin = PRmin(rho, W, S, Cd0, K),
      PR = PR(Vinf, rho, W, S, Cd0, K),
      TRmin = TRmin(W, ClCdstar),
      TR = TR(W, ClCd),
      PA = PA(sigma, P0),
      Pexc = Pexc(PA, PR),
      TA = TA(PA, Vinf),
      Texc = Texc(TA, TR)
    ) %>%
    rowwise() %>%
    mutate(VmaxP = VmaxP(PA, rho, W, S, Cd0, K, VmaxP1, VmaxP2))
}

