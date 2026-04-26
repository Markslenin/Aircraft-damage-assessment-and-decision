function y = clamp(x, lo, hi)
%CLAMP Element-wise saturation between lower and upper bounds.
%
%   y = clamp(x, lo, hi) returns min(max(x, lo), hi). Works on scalars,
%   vectors and matrices. Bounds may be scalars or arrays broadcastable to
%   the size of x.
%
%   This replaces the per-file private copies that were previously named
%   clamp / clamp_vector / sat.

y = min(max(x, lo), hi);
end
