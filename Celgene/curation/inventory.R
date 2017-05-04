

# generate a venn diagram

list(ND=inv)

library(venn)
venn::venn()
venn(5, ilab=TRUE, zcolor = "style")

# an equivalent command
venn("100 + 110 + 101 + 111")

# another equivalent command
venn(c("100", "110", "101", "111"))


# adding the labels for the intersections
venn("1--", ilabels = TRUE)

# using different parameters for the borders
venn(4, lty = 5, col = "navyblue")

# using ellipses
venn(4, lty = 5, col = "navyblue", ellipse = TRUE)

# a 5 sets Venn diagram
venn(5)

# a 5 sets Venn diagram using ellipses
venn(5, ellipse = TRUE)

# a 5 sets Venn diagram with intersection labels
venn(5, ilabels = TRUE)

# and a predefined color style
venn(5, ilabels = TRUE, zcolor = "style")

# a union of two sets
venn("1---- + ----1")

# with different colors
venn("1---- + ----1", zcolor = c("red", "blue"))

# same colors for the borders
venn("1---- + ----1", zcolor = c("red", "blue"), col = c("red", "blue"))

# 6 sets diagram
venn(6)

# 7 sets "Adelaide"
venn(7)


# artistic version
venn(c("1000000", "0100000", "0010000", "0001000",
       "0000100", "0000010", "0000001", "1111111"))

# when x is a list
set.seed(12345)
x <- list(First = 1:20, Second = 10:30, Third = sample(25:50, 15))
venn(x, snames = T)

# when x is a dataframe
set.seed(12345)
x <- as.data.frame(matrix(sample(0:1, 150, replace=TRUE), ncol=5))
venn(x)


# using disjunctive normal form notation
venn("A + Bc", snames = "A,B,C,D")

# the union of two sets, example from above
venn("A + E", snames = "A,B,C,D,E", zcol = c("red", "blue"))

# if the expression is a valid R statment, it works even without quotes
venn(A + bc + DE, snames = "A,B,C,D,E", zcol = c("red", "palegreen", "blue"))
