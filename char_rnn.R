library(keras)
library(readr)
library(stringr)
library(purrr)
library(tokenizers)

# Parameters --------------------------------------------------------------

maxlen <- 40

# Data Preparation --------------------------------------------------------

# Retrieve text
path <- "all.c"

# Load, collapse, and tokenize text
text <- read_lines(path) %>%
  str_to_lower() %>%
  str_c(collapse = "\n") %>%
  tokenize_characters(strip_non_alphanum = FALSE, simplify = TRUE)
text
print(sprintf("corpus length: %d", length(text)))

chars <- text %>%
  unique() %>%
  sort()
chars
print(sprintf("total chars: %d", length(chars)))  

# Cut the text in semi-redundant sequences of maxlen characters
dataset <- map(
  seq(1, length(text) - maxlen - 1, by = 3), 
  function(x) list(sentence = text[x:(x + maxlen - 1)], next_char = text[x + maxlen])
)

dataset[[1]]
dataset[[1]][[1]]
dataset[[1]][[2]]

dataset <- transpose(dataset)

dataset[[1]]
dataset[[1]][[1]]
dataset[[1]][[2]]
dataset[[2]]


# Vectorization
X <- array(0, dim = c(length(dataset$sentence), maxlen, length(chars)))
y <- array(0, dim = c(length(dataset$sentence), length(chars)))
dim(X)
dim(y)

for(i in 1:length(dataset$sentence)){
  
  X[i,,] <- sapply(chars, function(x){
    as.integer(x == dataset$sentence[[i]])
  })
  
  y[i,] <- as.integer(chars == dataset$next_char[[i]])
  
}

sample_mod <- function(preds, temperature = 1){
  preds <- log(preds)/temperature
  exp_preds <- exp(preds)
  preds <- exp_preds/sum(exp(preds))
  
  rmultinom(1, 1, preds) %>% 
    as.integer() %>%
    which.max()
}

model_exists <- TRUE

if(!model_exists) {
  model <- keras_model_sequential()
  
  model %>%
    layer_lstm(128, input_shape = c(maxlen, length(chars))) %>%
    layer_dense(length(chars)) %>%
    layer_activation("softmax")
  
  optimizer <- optimizer_rmsprop(lr = 0.01)
  
  model %>% compile(
    loss = "categorical_crossentropy", 
    optimizer = optimizer
  )
  
  for(iteration in 1:60){
    
    cat(sprintf("iteration: %02d ---------------\n\n", iteration))
    
    model %>% fit(
      X, y,
      batch_size = 128,
      epochs = 1
    )
    
    for(diversity in c(0.2, 0.5, 1, 1.2)){
      
      cat(sprintf("diversity: %f ---------------\n\n", diversity))
      
      start_index <- sample(1:(length(text) - maxlen), size = 1)
      sentence <- text[start_index:(start_index + maxlen - 1)]
      generated <- ""
      
      for(i in 1:400){
        
        x <- sapply(chars, function(x){
          as.integer(x == sentence)
        })
        x <- array_reshape(x, c(1, dim(x)))
        
        preds <- predict(model, x)
        next_index <- sample_mod(preds, diversity)
        next_char <- chars[next_index]
        
        generated <- str_c(generated, next_char, collapse = "")
        sentence <- c(sentence[-1], next_char)
        
      }
      
      cat(generated)
      cat("\n\n")
      
    }
  }
  model %>% save_model_hdf5("char_rnn_60.h5")
  
} else {
  
  model <- load_model_hdf5("char_rnn_60.h5")
}

