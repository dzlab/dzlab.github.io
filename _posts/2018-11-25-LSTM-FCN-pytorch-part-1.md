---
layout: post
comments: true
title: Implementing LSTM-FCN in pytorch - Part I
categories: timeseries
---

Timeseris classification problems can be approached through a DL and non-DL approaches. Wether one approaches works better than the other may depend on the problem. Within DL there are 3 main approaches:

- Recurrent Neural Networks (RNN) like LSTM or GRU
- Convolutional Neural Networks (CNN)
- Hybrid models (combines RNN with CNN)

RNN are the ones been classically used for Timeseries problems, but in the last few years CNNs and Hybrid models started showing better performance. Here are some of the approaches I consider more interesting:

**RNN**
- Plain/ stacked LSTM / GRU
- Dilated Recurrent Neural Networks (Dilated RNN) (S. Chang, NIPs 2017) - [paper](https://arxiv.org/abs/1710.02224) [code](https://github.com/code-terminator/DilatedRNN)

**CNN**
1. Transfer learning applied to time series images (ts —> image —> resnet):

    1.1. Single image: 1-3 channel images (an encoder per channel) in a single resnet, [notebook](https://github.com/dzlab/deepprojects/blob/master/timeseries/Timeseries_Earthquakes.ipynb)

    1.2. Multi-image: 1-3 channel images (an encoder per channel) in parallel resnets [notebook]()

2. Training from scratch:

    2.1. Tiled Convolutional Neural Networks: Encoding Time Series as Images for Visual Inspection and Classification Using Tiled Convolutional Neural Networks (Z. Wang, 2015) [paper](https://aaai.org/ocs/index.php/WS/AAAIW15/paper/viewFile/10179/10251) [code](https://github.com/cauchyturing/Imaging-time-series-to-improve-classification-and-imputation)

    2.2. Temporal convolutional network (TCNs): An Empirical Evaluation of Generic Convolutional and Recurrent Networks for Sequence Modeling 1, (S. Bai, 2018), [paper](https://arxiv.org/abs/1803.01271) [code](https://github.com/locuslab/TCN)

    2.3. TrellisNet (modified TCN): Trellis Networks for Sequence Modeling (S. Bai, 2018), [paper](https://arxiv.org/abs/1810.06682) [code](https://github.com/locuslab/trellisnet)

**Hybrid models**

1. DeepConvLSTM: Deep Convolutional and LSTM Recurrent Neural Networks for Multimodal Wearable Activity Recognition (Ordoñez, 2016) [paper](https://www.mdpi.com/1424-8220/16/1/115/pdf) [code](https://scrutinizer-ci.com/g/NLeSC/mcfly/inspections/b8ffce89-d59a-4d05-a6c2-3bc6831ba9c1/code-structure/py-function/generate_DeepConvLSTM_model?expandCoverage=1)

2. LSTM Fully Convolutional Network (Temporal convolutions + LSTM in parallel):

    2.1. LSTM Fully Convolutional Networks for Time Series Classification 1 (F. Karim, 2017), current state of the art in may UCR univariate datasets, [paper](https://arxiv.org/abs/1709.05206) [code](https://github.com/houshd/LSTM-FCN)

    2.2. Multivariate LSTM-FCNs for Time Series Classification 1 (F. Karim, 2018), current state of the art in may UCR multivariate datasets, [paper](https://arxiv.org/abs/1801.04503) [code](https://github.com/titu1994/MLSTM-FCN)


The follwoing article implements Multivariate LSTM-FCN architecture in pytorch.

## Network Architecture

![LSTM-FCN_Architecture]({{ "/assets/20181125-lstm-fcn_architecture.png" | absolute_url }})

### LSTM block

The LSTM block is composed mainly of a [LSTM](https://pytorch.org/docs/stable/nn.html#lstm) (alternatively Attention LSTM) layer, followed by a [Dropout](https://pytorch.org/docs/stable/nn.html#dropout) layer.

A [shuffle](https://pytorch.org/docs/stable/tensors.html?highlight=transpose#torch.Tensor.transpose) layer is used at the begning of this block in case the number of time steps `N` (sequence length of the LSTM layer), is greater than the number of variables `M`.

This tricks improves the efficiency as the LSTM layer since it will require `M` time steps to process `N` variables, instead of `N` time steps to process `M` variables each timestep in case no shuffle is applied.

In pytorch, the LSRM block looks like the following:
{% highlight python %}
class BlockLSTM(nn.Module):
    def __init__(self, time_steps, num_variables, lstm_hs=256, dropout=0.8, attention=False):
        super().__init__()
        self.lstm = nn.LSTM(input_size=time_steps, hidden_size=lstm_hs, num_layers=num_variables)
        self.dropout = nn.Dropout(p=dropout)
    def forward(self, x):
        # input is of the form (batch_size, num_variables, time_steps), e.g. (128, 1, 512)
        x = torch.transpose(x, 0, 1)
        # lstm layer is of the form (num_variables, batch_size, time_steps)
        x = self.lstm(x)
        # dropout layer input shape:
        y = self.dropout(x)
        # output shape is of the form ()
        return y
{% endhighlight %}

### FCN block
The core component of fully convolutional block is a convolutional block that contains:
- [Convolutional](https://pytorch.org/docs/stable/nn.html#conv1d) layer with filter size of 128 or 256.
- [Batch normalization](https://pytorch.org/docs/stable/nn.html#batchnorm1d) layer with a momentum of 0.99 and epsilon of 0.001.
- A [ReLU](https://pytorch.org/docs/stable/nn.html#relu) activation at the end of the block.
- An optional Squeeze and Excite block.

In pytorch, the a convolutional block looks like the following:
{% highlight python %}
class BlockFCNConv(nn.Module):
    def __init__(self, in_channel=1, out_channel=128, kernel_size=8, momentum=0.99, epsilon=0.001, squeeze=False):
        super().__init__()
        self.conv = nn.Conv1d(in_channel, out_channel, kernel_size=kernel_size)
        self.batch_norm = nn.BatchNorm1d(num_features=out_channel, eps=epsilon, momentum=momentum)
        self.relu = nn.ReLU()
    def forward(self, x):
        # input (batch_size, num_variables, time_steps), e.g. (128, 1, 512)
        x = self.conv(x)
        # input (batch_size, out_channel, L_out)
        x = self.batch_norm(x)
        # same shape as input
        y = self.relu(x)
        return y
{% endhighlight %}
The fully convolutional block contains three of these convolutional blocks, used as a feature extractor. Then it uses a global average pooling layer to generate channel-wise statistics.

In pytorch, a FCN block would look like:
{% highlight python %}
class BlockFCN(nn.Module):
    def __init__(self, time_steps, channels=[1, 128, 256, 128], kernels=[8, 5, 3], mom=0.99, eps=0.001):
        super().__init__()
        self.conv1 = BlockFCNConv(channels[0], channels[1], kernels[0], momentum=mom, epsilon=eps, squeeze=True)
        self.conv2 = BlockFCNConv(channels[1], channels[2], kernels[1], momentum=mom, epsilon=eps, squeeze=True)
        self.conv3 = BlockFCNConv(channels[2], channels[3], kernels[2], momentum=mom, epsilon=eps)
        output_size = time_steps - sum(kernels) + len(kernels)
        self.global_pooling = nn.AvgPool1d(kernel_size=output_size)
    def forward(self, x):
        x = self.conv1(x)
        x = self.conv2(x)
        x = self.conv3(x)
        # apply Global Average Pooling 1D
        y = self.global_pooling(x)
        return y
{% endhighlight %}

### LSTM-FCN
Finally, putting together the previous blocks to construct the LSTM-FCN architecture by concatenating the out of the blocks and passing it throgh a softmax activation to generate the final output.
{% highlight python %}
class LSTMFCN(nn.Module):
    def __init__(self, time_steps, num_variables):
        super().__init__()
        self.lstm_block = BlockLSTM(time_steps, num_variables)
        self.fcn_block = BlockFCN(time_steps)
        self.softmax = nn.Softmax()
    def forward(self, x):
        # input is (batch_size, time_steps), it has to be (batch_size, 1, time_steps)
        x = x.unsqueeze(1)
        # pass input through LSTM block
        x1 = self.lstm_block(x)
        # pass input through FCN block
        x2 = self.fcn_block(x)
        # concatenate blocks output
        x = torch.cat([x1, x2], 1)
        # pass through Softmax activation
        y = self.softmax(x)
{% endhighlight %}

## Training
[Part II]() discusses the training setup of the LSTM-FCN architecture using different Datasets.

{% include disqus.html %}