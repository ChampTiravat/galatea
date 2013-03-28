% Version 1.000
%
% Code provided by Ruslan Salakhutdinov 
%
% Permission is granted for anyone to copy, use, modify, or distribute this
% program and accompanying programs and documents for any purpose, provided
% this copyright notice is retained and prominently displayed, along with
% a note saying that the original programs are available from our
% web page.
% The programs and documents are distributed without any warranty, express or
% implied.  As the programs were written for research purposes only, they have
% not been tested to the degree that would be advisable in any important
% application.  All use of these programs is entirely at the user's own risk.


load /u/goodfeli/galatea/pddbm/pddbm_train_features.mat
batchdata = zeros(100,784,600);
for i=1:600
	start = (i-1)*100+1;
	stop = i*100;
	batchdata(:,:,i) = X(start:stop,:);
end
assert( max(max(X))<1.)
assert( max(max(max(batchdata))) < 1.)
load /u/goodfeli/galatea/pddbm/pddbm_test_features.mat
testbatchdata = zeros(100,784,100);
for i=1:100
	start = (i-1)*100+1;
	stop = i*100;
	testbatchdata(:,:,i) = X(start:stop,:);
end


test_err=[];
test_crerr=[];
train_err=[];
train_crerr=[];

fprintf(1,'\nTraining discriminative model on MNIST by minimizing cross entropy error. \n');
fprintf(1,'60 batches of 1000 cases each. \n');

[numcases numdims numbatches]=size(batchdata);
assert(max(max(max(batchdata)))<1.)
N=numcases; 


safeguardbatchdata = batchdata;
safeguardtestbatchdata = testbatchdata;

%load fullmnist_dbm
load ../dump/after_joint_train
[numdims numhids] = size(vishid);
[numhids numpens] = size(hidpen); 

batchdata = safeguardbatchdata;
testbatchdata = safeguardtestbatchdata;

%%%%%% Preprocess the data %%%%%%%%%%%%%%%%%%%%%%

[testnumcases testnumdims testnumbatches]=size(testbatchdata);
assert(max(max(max(batchdata)))<1.)
N=testnumcases;
temp_h1_test = zeros(testnumcases,numhids,testnumbatches);
temp_h2_test = zeros(testnumcases,numpens,testnumbatches); 
for batch = 1:testnumbatches
   data = [testbatchdata(:,:,batch)];
   [temp_h1, temp_h2] = ...
       mf_class(data,vishid,hidbiases,visbiases,hidpen,penbiases);
   temp_h1_test(:,:,batch) = temp_h1;
   temp_h2_test(:,:,batch) = temp_h2;
end  
assert(max(max(max(batchdata)))<1.)

[numcases numdims numbatches]=size(batchdata);
N=numcases;
temp_h1_train = zeros(numcases,numhids,numbatches);
temp_h2_train = zeros(numcases,numpens,numbatches);
for batch = 1:numbatches
   data = [batchdata(:,:,batch)];
   [temp_h1, temp_h2] = ...
     mf_class(data,vishid,hidbiases,visbiases,hidpen,penbiases);
   temp_h1_train(:,:,batch) = temp_h1;
   temp_h2_train(:,:,batch) = temp_h2;
end
assert(max(max(max(batchdata)))<1.)


train_X = zeros(60000,784);
test_X = zeros(10000,784);
train_H = zeros(60000,500);
test_H = zeros(10000,500);
train_G = zeros(60000,1000);
test_G = zeros(10000,1000);

for i=1:600
	start = (i-1)*100+1;
	stop  = i * 100;
	train_X(start:stop,:) = batchdata(:,:,i);
	train_H(start:stop,:) = temp_h1_train(:,:,i);
	train_G(start:stop,:) = temp_h2_train(:,:,i);
end
assert(max(max(max(train_X)))<1.)
for i=1:100
	start = (i-1)*100+1;
	stop  = i * 100;
	test_X(start:stop,:) = testbatchdata(:,:,i);
	test_H(start:stop,:) = temp_h1_test(:,:,i);
	test_G(start:stop,:) = temp_h2_test(:,:,i);
end

save('dbm_feat.mat','train_X','train_H','train_G','test_X','test_H','test_G')
keyboard

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

w1_penhid = hidpen';
w1_vishid = vishid;
w2 = hidpen;
h1_biases = hidbiases; h2_biases = penbiases; 

w_class = 0.1*randn(numpens,10); 
topbiases = 0.1*randn(1,10);

for epoch = 1:maxepoch 

%%%% TEST STATS 
%%%% Error rates 
   [testnumcases testnumdims testnumbatches]=size(testbatchdata);
   N=testnumcases;
   bias_hid= repmat(h1_biases,N,1);
   bias_pen = repmat(h2_biases,N,1);
   bias_top = repmat(topbiases,N,1);

   err=0;
   err_cr=0;
   counter=0;  
   for batch = 1:testnumbatches
     data = [testbatchdata(:,:,batch)];
     temp_h2 = temp_h2_test(:,:,batch); 
     target = [testbatchtargets(:,:,batch)]; 

     w1probs = 1./(1 + exp(-data*w1_vishid -temp_h2*w1_penhid - bias_hid  )); 
     w2probs = 1./(1 + exp(-w1probs*w2 - bias_pen)); 
     targetout = exp(w2probs*w_class + bias_top );
     targetout = targetout./repmat(sum(targetout,2),1,10);
     [I J]=max(targetout,[],2); 
     [I1 J1]=max(target,[],2); 
     counter=counter+length(find(J~=J1));  
     err_cr = err_cr- sum(sum( target(:,1:end).*log(targetout))) ;
   end

   test_err(epoch)=counter;
   test_crerr(epoch)=err_cr;
   fprintf(1,'\nepoch %d test  misclassification err %d (out of 10000),  test cross entropy error %f \n',epoch,test_err(epoch),test_crerr(epoch));
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

  %%%% TRAINING STATS
  %%%% Error rates
  [numcases numdims numbatches]=size(batchdata);
  N=numcases;
  err=0;
  err_cr=0;
  counter=0;
  for batch = 1:numbatches
    data = [batchdata(:,:,batch)];
    temp_h2 = temp_h2_train(:,:,batch); 
    target = [batchtargets(:,:,batch)];

    w1probs = 1./(1 + exp(-data*w1_vishid -temp_h2*w1_penhid - bias_hid  ));
    w2probs = 1./(1 + exp(-w1probs*w2 - bias_pen));
    targetout = exp(w2probs*w_class + bias_top );
    targetout = targetout./repmat(sum(targetout,2),1,10);
    [I J]=max(targetout,[],2);
    [I1 J1]=max(target,[],2);
    counter=counter+length(find(J~=J1));

    err_cr = err_cr- sum(sum( target(:,1:end).*log(targetout))) ;
  end

  train_err(epoch)=counter;
  train_crerr(epoch)=err_cr;
  fprintf(1,'epoch %d train misclassification err %d train (out of 60000), train cross entropy error %f \n',epoch, train_err(epoch),train_crerr(epoch));
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

  save backprop_weights w1_vishid w1_penhid w2 w_class h1_biases h2_biases topbiases test_err test_crerr train_err train_crerr
 
%%% Do Conjugate Gradient Optimization 

  rr = randperm(600); 
  for batch = 1:numbatches/100
    fprintf(1,'epoch %d batch %d\r',epoch,batch);
    data = zeros(10000,numdims); 
    temp_h2 = zeros(10000,numpens); 
    targets = zeros(10000,10); 
    tt1=(batch-1)*100+1:batch*100; 
    for tt=1:100
      data( (tt-1)*100+1:tt*100,:) = batchdata(:,:,rr(tt1(tt))); 
      temp_h2( (tt-1)*100+1:tt*100,:) = temp_h2_train(:,:,rr(tt1(tt))); 
      targets( (tt-1)*100+1:tt*100,:) = batchtargets(:,:,rr(tt1(tt))); 
    end  

%%%%%%%% DO CG with 3 linesearches 

    VV = [w1_vishid(:)' w1_penhid(:)' w2(:)' w_class(:)' h1_biases(:)' h2_biases(:)' topbiases(:)']';
    Dim = [numdims; numhids; numpens; ];

% checkgrad('CG_MNIST_INIT',VV,10^-5,Dim,data,targets);
    max_iter=3; 
    if epoch<6
       [X, fX, num_iter,ecg_XX] = minimize(VV,'CG_MNIST_INIT',max_iter,Dim,data,targets,temp_h2);
    else
       [X, fX, num_iter,ecg_XX] = minimize(VV,'CG_MNIST',max_iter,Dim,data,targets,temp_h2);
    end 
    w1_vishid = reshape(X(1:numdims*numhids),numdims,numhids);
    xxx = numdims*numhids;
    w1_penhid = reshape(X(xxx+1:xxx+numpens*numhids),numpens,numhids);
    xxx = xxx+numpens*numhids;
    w2 = reshape(X(xxx+1:xxx+numhids*numpens),numhids,numpens);
    xxx = xxx+numhids*numpens;
    w_class = reshape(X(xxx+1:xxx+numpens*10),numpens,10);
    xxx = xxx+numpens*10;
    h1_biases = reshape(X(xxx+1:xxx+numhids),1,numhids);
    xxx = xxx+numhids;
    h2_biases = reshape(X(xxx+1:xxx+numpens),1,numpens);
    xxx = xxx+numpens;
    topbiases = reshape(X(xxx+1:xxx+10),1,10);
    xxx = xxx+10;

  end

end


