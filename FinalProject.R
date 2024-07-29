# Load the necessary R packages:
library(leaps)
library(bestglm)
library(magrittr)
library(dplyr)
library(caret)

# Load the CSV data and extract the response and predictor variables
# (removing datapoint for North Korea and choosing a subset of the predictor
# variables based on domain knowledge)
data <- read.csv("countries.csv") %>%
  filter(name != "North Korea")
data <- data %>%
  mutate(airports_roadways_interaction = airports + roadways, population_log = log(population), gdpPPP_percap_log = log(gdpPPP_percap), labor_force_log = log(labor_force), land_area_log = log(land_area), coastline_log = log(coastline), refined_petrol_consumption_log = log(refined_petrol_consumption), co2_emisssions_energy_consumption_log = log(co2_emisssions_energy_consumption), airports_roadways_interaction_log = log(airports_roadways_interaction))
y <- data[,"life_exp_at_birth"]
predictors <- data %>%
  select(population_log, birth_rate, death_rate, gdpPPP_percap_log, labor_force_log, land_area_log, land_use_agricultural, urbanization, refined_petrol_consumption_log, co2_emisssions_energy_consumption_log, airports_roadways_interaction_log, democracy_index, health_spend_pct_gdp)


# Apply best subsets procedure using Mallows’ Cp criterion
leaps.sub <- leaps(x = as.matrix(predictors), y = y)
plot(leaps.sub$size, leaps.sub$Cp, xlab = "p", ylab = expression(C[p]))
lines(leaps.sub$size, leaps.sub$size, col = 2)
select <- leaps.sub$Cp == min(leaps.sub$Cp)
selected_predictors_1 <- colnames(predictors)[leaps.sub$which[select, ]]
print(selected_predictors_1)

# Find the best model based on AIC
data.matrix=data.frame(cbind(predictors,y))
bestglm(data.matrix,IC="AIC")

# Find the best model based on BIC
data.matrix=data.frame(cbind(predictors,y))
bestglm(data.matrix,IC="BIC")

# Run bestglm
best_bic_model <- bestglm(data.matrix, IC = "BIC")
best_model <- best_bic_model$BestModel
selected_predictors_2 <- names(coef(best_model)[-1])
print(selected_predictors_2)

# Fit a linear regression model based on our selection of covariates
model1 <- lm(life_exp_at_birth ~ ., data = data[, c("life_exp_at_birth", selected_predictors_1)])
summary(model1)
model2 <- lm(life_exp_at_birth ~ ., data = data[, c("life_exp_at_birth", selected_predictors_2)])
summary(model2)

predictors_used <- predictors <- data %>%
  select(birth_rate, death_rate, gdpPPP_percap_log, urbanization, urbanization, health_spend_pct_gdp)
print(selected_predictors_2)
  
# Diagnostic Plots

# Fit model and collect fits and residuals
y.hat <- predict(model2)
deleted_res <- rstudent(model2)

# Pairs plot
selected_data <- data.matrix[, c("y", selected_predictors_2)]
pairs(selected_data)

# Plot studentized deleted residuals against each predictor variable
for (col in colnames(predictors_used)) {
  plot(deleted_res ~ predictors[[col]], main = paste("Deleted Residuals vs", col), xlab = col, ylab = "Deleted Residuals")
}

# Plot studentized deleted residuals against fitted points
plot(deleted_res ~ y.hat)

# Plot studentized deleted residuals against index sequence (or time)
plot(deleted_res ~ seq(1, nrow(data), 1))

# Histogram and box plot of studentized deleted residuals
hist(deleted_res, breaks = 50)
boxplot(deleted_res)

# Normal QQ Plot of studentized deleted residuals
qqnorm(deleted_res)


# Model Validation

# Data Splitting
# Set seed for reproducibility
set.seed(123)

# Create a random index for data splitting (e.g., 80% training, 20% testing)
train_index <- sample(1:nrow(data), 0.8 * nrow(data))

# Split the data
train_data <- data[train_index, ]
test_data <- data[-train_index, ]

# Fit the model on the training data
model_train <- lm(life_exp_at_birth ~ ., data = train_data[, c("life_exp_at_birth", selected_predictors_2)])

# Predict on the test data
predictions <- predict(model_train, newdata = test_data)

# Evaluate the model on the test data
mse <- mean((test_data$life_exp_at_birth - predictions)^2)
print(paste("Mean Squared Prediction Error on Test Data: ", mse))



# K-fold Cross Validation
# Define the number of folds
k <- 5

# Create folds
folds <- createFolds(data$life_exp_at_birth, k = k)

# Initialize a vector to store cross-validation results
cv_results <- numeric(k)

# Perform k-fold cross-validation
for (i in 1:k) {
  # Split the data into training and validation sets
  train_data <- data[-folds[[i]], ]
  valid_data <- data[folds[[i]], ]
  
  # Fit the model on the training data
  model_cv <- lm(life_exp_at_birth ~ ., data = train_data[, c("life_exp_at_birth", selected_predictors_2)])
  
  # Predict on the validation data
  predictions_cv <- predict(model_cv, newdata = valid_data)
  
  # Evaluate the model on the validation data (e.g., mean squared error)
  mse_cv <- mean((valid_data$life_exp_at_birth - predictions_cv)^2)
  
  # Store the result
  cv_results[i] <- mse_cv
}

# Calculate the average mean squared error across folds
average_mse <- mean(cv_results)
print(paste("Average Mean Squared Prediction Error across", k, "folds: ", average_mse))

