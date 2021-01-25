---
layout: post
comments: true
title: Tools for High Performance Python
excerpt: Learn about python tools to profile and improve the performance of your programs.
categories: ml
tags: [python]
toc: true
img_excerpt:
---

In this article we will see how to profile python program and some of the tools at hand to improve the performance. As a toy example we will consider the case where we have a Pandas DataFrame of many columns and we want to apply a function to each row to do some heavy caclulations.

```
pip install line-profiler
pip install bulwark
pip install swifter
pip install numba
pip install dask
```

Let's a create a toy dataframe of 100k rows and 14 columns:
```python
data = np.random.randint(0, 100, (100000, 14))
df = pd.DataFrame(data).astype("float64")
```

As a toy function, we pick a linear regression on the columns of the dataframe to calculate the slope of a line.

A first solution would to train sklearn `LinearRegression` on every row, and defining X as the index in the row and y as the actual values. Upon training we take the first coeffition of the linear regression as output.
```python
from sklearn.linear_model import LinearRegression

def ols_sklearn(row):
  """Solve OLS using scikit-learn's LinearRegression"""
  est = LinearRegression()
  X = np.arange(row.shape[0]).reshape(-1, 1) # shape (14, 1)
  y = row.values  # shape (14,)
  # note that the intercept is built inside LinearRegression
  est.fit(X, y)
  m = est.coef_[0] # note c is est.intercept_
  return m
```

We could also try another implementation that we deem will outperform the first one. In this case using numpy's least-squares resolver for linear matrix equation [lstsq](https://numpy.org/doc/stable/reference/generated/numpy.linalg.lstsq.html).
```python
import numpy as np

def ols_lstsq(row):
  """Solve OLS using numpy.linalg.lstsq"""
  # build X values for [0, 13]
  X = np.arange(row.shape[0]) # shape (14,)
  ones = np.ones(row.shape[0]) # constant used to build intercept
  A = np.vstack((X, ones)).T # shape (14, 2)
  # lstsq returns the coefficient and intercept as the first result followed by the residuals and other items
  m, c = np.linalg.lstsq(A, row.values, rcond=-1)[0]
  return m
```

We first make sure both implementations output similar result using numpy's [assert_array_almost_equal](https://numpy.org/doc/stable/reference/generated/numpy.testing.assert_array_almost_equal.html)
```python
from numpy.testing import assert_array_almost_equal

results_sklearn = df.apply(ols_sklearn, axis=1)
results_lstsq = df.apply(ols_lstsq, axis=1)
assert_array_almost_equal(results_sklearn, results_lstsq)
```

After making sure that our initial solution to the problem behaves the same, we can compare their performances with `timeit`
```
>>> %timeit ols_sklearn(df.iloc[0])
The slowest run took 56.09 times longer than the fastest. This could mean that an intermediate result is being cached.
1000 loops, best of 3: 452 µs per loop

>>> %timeit ols_lstsq(df.iloc[0])
The slowest run took 30.11 times longer than the fastest. This could mean that an intermediate result is being cached.
10000 loops, best of 3: 175 µs per loop
```

At a first glance and with no surprise numpy solution out performed sklearn version. This is because even though sklearn uses under the hood numpy's `lstsq` it also does lot additional safety checks (e.g. division by zero) that could add overhead.

To identity where exactly sklearn overhead is introduced we use a python profiling tool call [line_profiler](https://github.com/pyutils/line_profiler)

```python
from line_profiler import LineProfiler

row = df.iloc[0]
est = LinearRegression()
X = np.arange(row.shape[0]).reshape(-1, 1)

lp = LineProfiler(est.fit)
print("Run on a single row")
lp.run("est.fit(X, row.values)")
lp.print_stats()
```

The output will looks as follows, for each line in the `fit` method we get the time it took, the percentage as well as the number of hits.
```
Run on a single row
Timer unit: 1e-06 s

Total time: 0.001564 s
File: /usr/local/lib/python3.6/dist-packages/sklearn/linear_model/_base.py
Function: fit at line 467

Line #      Hits         Time  Per Hit   % Time  Line Contents
==============================================================
   467                                               def fit(self, X, y, sample_weight=None):
   468                                                   """
   469                                                   Fit linear model.
   470                                           
   471                                                   Parameters
   472                                                   ----------
   473                                                   X : {array-like, sparse matrix} of shape (n_samples, n_features)
   474                                                       Training data
   475                                           
   476                                                   y : array-like of shape (n_samples,) or (n_samples, n_targets)
   477                                                       Target values. Will be cast to X's dtype if necessary
   478                                           
   479                                                   sample_weight : array-like of shape (n_samples,), default=None
   480                                                       Individual weights for each sample
   481                                           
   482                                                       .. versionadded:: 0.17
   483                                                          parameter *sample_weight* support to LinearRegression.
   484                                           
   485                                                   Returns
   486                                                   -------
   487                                                   self : returns an instance of self.
   488                                                   """
   489                                           
   490         1          5.0      5.0      0.3          n_jobs_ = self.n_jobs
   491         1          3.0      3.0      0.2          X, y = check_X_y(X, y, accept_sparse=['csr', 'csc', 'coo'],
   492         1        736.0    736.0     47.1                           y_numeric=True, multi_output=True)
   493                                           
   494         1          3.0      3.0      0.2          if sample_weight is not None:
   495                                                       sample_weight = _check_sample_weight(sample_weight, X,
   496                                                                                            dtype=X.dtype)
   497                                           
   498         1          5.0      5.0      0.3          X, y, X_offset, y_offset, X_scale = self._preprocess_data(
   499         1          3.0      3.0      0.2              X, y, fit_intercept=self.fit_intercept, normalize=self.normalize,
   500         1          2.0      2.0      0.1              copy=self.copy_X, sample_weight=sample_weight,
   501         1        517.0    517.0     33.1              return_mean=True)
   502                                           
   503         1          4.0      4.0      0.3          if sample_weight is not None:
   504                                                       # Sample weight can be implemented via a simple rescaling.
   505                                                       X, y = _rescale_data(X, y, sample_weight)
   506                                           
   507         1          4.0      4.0      0.3          if sp.issparse(X):
   508                                                       X_offset_scale = X_offset / X_scale
   509                                           
   510                                                       def matvec(b):
   511                                                           return X.dot(b) - b.dot(X_offset_scale)
   512                                           
   513                                                       def rmatvec(b):
   514                                                           return X.T.dot(b) - X_offset_scale * np.sum(b)
   515                                           
   516                                                       X_centered = sparse.linalg.LinearOperator(shape=X.shape,
   517                                                                                                 matvec=matvec,
   518                                                                                                 rmatvec=rmatvec)
   519                                           
   520                                                       if y.ndim < 2:
   521                                                           out = sparse_lsqr(X_centered, y)
   522                                                           self.coef_ = out[0]
   523                                                           self._residues = out[3]
   524                                                       else:
   525                                                           # sparse_lstsq cannot handle y with shape (M, K)
   526                                                           outs = Parallel(n_jobs=n_jobs_)(
   527                                                               delayed(sparse_lsqr)(X_centered, y[:, j].ravel())
   528                                                               for j in range(y.shape[1]))
   529                                                           self.coef_ = np.vstack([out[0] for out in outs])
   530                                                           self._residues = np.vstack([out[3] for out in outs])
   531                                                   else:
   532                                                       self.coef_, self._residues, self.rank_, self.singular_ = \
   533         1        240.0    240.0     15.3                  linalg.lstsq(X, y)
   534         1          3.0      3.0      0.2              self.coef_ = self.coef_.T
   535                                           
   536         1          1.0      1.0      0.1          if y.ndim == 1:
   537         1         15.0     15.0      1.0              self.coef_ = np.ravel(self.coef_)
   538         1         22.0     22.0      1.4          self._set_intercept(X_offset, y_offset, X_scale)
   539         1          1.0      1.0      0.1          return self

```

From the ouput we can clear see that most of the time in `fit` was spent in either safety checks or data preprocessing and all that before calling numpy's `lstsq`.

Here is the profiling output for safety checks
```
   491         1          3.0      3.0      0.2          X, y = check_X_y(X, y, accept_sparse=['csr', 'csc', 'coo'],
   492         1        736.0    736.0     47.1                           y_numeric=True, multi_output=True)
```
Here is the profiling output of the data preprocessing
```
   498         1          5.0      5.0      0.3          X, y, X_offset, y_offset, X_scale = self._preprocess_data(
   499         1          3.0      3.0      0.2              X, y, fit_intercept=self.fit_intercept, normalize=self.normalize,
   500         1          2.0      2.0      0.1              copy=self.copy_X, sample_weight=sample_weight,
   501         1        517.0    517.0     33.1              return_mean=True)

```
Here is the profiling output for the actual training with `lstsq`
```
   532                                                       self.coef_, self._residues, self.rank_, self.singular_ = \
   533         1        240.0    240.0     15.3                  linalg.lstsq(X, y)
```