% File: EM_HMM.m
%
% Copyright (C) Daphne Koller, Stanford Univerity, 2012

function [P loglikelihood ClassProb PairProb] = EM_HMM(actionData, poseData, G, InitialClassProb, InitialPairProb, maxIter)

% INPUTS
% actionData: structure holding the actions as described in the PA
% poseData: N x 10 x 3 matrix, where N is number of poses in all actions
% G: graph parameterization as explained in PA description
% InitialClassProb: N x K matrix, initial allocation of the N poses to the K
%   states. InitialClassProb(i,j) is the probability that example i belongs
%   to state j.
%   This is described in more detail in the PA.
% InitialPairProb: V x K^2 matrix, where V is the total number of pose
%   transitions in all HMM action models, and K is the number of states.
%   This is described in more detail in the PA.
% maxIter: max number of iterations to run EM

% OUTPUTS
% P: structure holding the learned parameters as described in the PA
% loglikelihood: #(iterations run) x 1 vector of loglikelihoods stored for
%   each iteration
% ClassProb: N x K matrix of the conditional class probability of the N examples to the
%   K states in the final iteration. ClassProb(i,j) is the probability that
%   example i belongs to state j. This is described in more detail in the PA.
% PairProb: V x K^2 matrix, where V is the total number of pose transitions
%   in all HMM action models, and K is the number of states. This is
%   described in more detail in the PA.

% Initialize variables
N = size(poseData, 1);
K = size(InitialClassProb, 2);
L = size(actionData, 2); % number of actions
V = size(InitialPairProb, 1);

ClassProb = InitialClassProb;
PairProb = InitialPairProb;

loglikelihood = zeros(maxIter,1);

P.c = [];
P.clg.sigma_x = [];
P.clg.sigma_y = [];
P.clg.sigma_angle = [];

firstPoseIdxs = zeros(length(actionData), 1);
for actionIdx=1:length(actionData)
  firstPoseIdxs(actionIdx) = actionData(actionIdx).marg_ind(1);
end

% EM algorithm
for iter=1:maxIter
  % M-STEP to estimate parameters for Gaussians
  % Fill in P.c, the initial state prior probability (NOT the class
  % probability as in PA8 and EM_cluster.m)
  % Fill in P.clg for each body part and each class
  % Make sure to choose the right parameterization based on G(i,1)
  % Hint: This part should be similar to your work from PA8 and
  % EM_cluster.m
  P = LearnCPDsGivenGraph(poseData, G, ClassProb);
  P.c = mean(ClassProb(firstPoseIdxs, :));

  P.transMatrix = zeros(K, K);
  for poseIdx=1:size(PairProb, 1)
    P.transMatrix += reshape(PairProb(poseIdx, :), K, K);
  end

  % Add Dirichlet prior based on size of poseData to avoid 0
  % probabilities
  P.transMatrix = P.transMatrix + size(PairProb,1) * .05;

  P.transMatrix = P.transMatrix ./ sum(P.transMatrix, 2);

  % E-STEP preparation: compute the emission model factors (emission
  % probabilities) in log space for each
  % of the poses in all actions = log( P(Pose | State) )
  % Hint: This part should be similar to (but NOT the same as) your code
  % in EM_cluster.m

  P2 = P;
  P2.c = ones(K, 1);
  logEmissionProbs = zeros(N, K);
  for poseIdx=1:N
    example = squeeze(poseData(poseIdx, :, :));
    logEmissionProbs(poseIdx, :) = ComputeExampleLogProbs(P2, G, example);
  end
  logEmissionProbs = logEmissionProbs;

  % Looks like correct up to this point!

  % E-STEP to compute expected sufficient statistics
  % ClassProb contains the conditional class probabilities for each pose
  % in all actions
  % PairProb contains the expected sufficient statistics for the
  % transition CPDs (pairwise transition probabilities)
  % Also compute log likelihood of dataset for this iteration
  % You should do inference and compute everything in log space, only
  % converting to probability space at the end
  % Hint: You should use the logsumexp() function here to do probability
  % normalization in log space to avoid numerical issues

  [ClassProb, PairProb] = BaumWelch(
                              P,
                              actionData,
                              poseData,
                              logEmissionProbs);
  loglikelihood(iter) = 0;

  % Print out loglikelihood
  disp(sprintf('EM iteration %d: log likelihood: %f', ...
    iter, loglikelihood(iter)));
  if exist('OCTAVE_VERSION')
    fflush(stdout);
  end

  % Check for overfitting by decreasing loglikelihood
  if iter > 1
    if loglikelihood(iter) < loglikelihood(iter-1)
      break;
    end
  end
end

% Remove iterations if we exited early
loglikelihood = loglikelihood(1:iter);
