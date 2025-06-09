import { createSlice, createAsyncThunk, PayloadAction } from "@reduxjs/toolkit";
import { Order } from "../../utils/types";
import { api } from "../../utils/services/apiService";

interface OrderState {
  orders: Order[];
  sellerOrders: Order[];
  currentOrder: Order | null;
  loading: "idle" | "pending" | "succeeded" | "failed";
  error: string | null;
}

const initialState: OrderState = {
  orders: [],
  sellerOrders: [],
  currentOrder: null,
  loading: "idle",
  error: null,
};

export const createOrder = createAsyncThunk<
  Order,
  {
    product: string;
    seller: string;
    amount: number;
  },
  { rejectValue: string }
>("orders/create", async (orderData, { rejectWithValue }) => {
  try {
    const response = await api.createOrder(orderData);
    if (!response.ok) {
      return rejectWithValue(response.error || "Failed to create order");
    }
    return response.data;
  } catch (error) {
    return rejectWithValue(
      error instanceof Error ? error.message : "Unknown error"
    );
  }
});

export const fetchUserOrders = createAsyncThunk<
  Order[],
  boolean | undefined,
  { rejectValue: string }
>(
  "orders/fetchUserOrders",
  async (forceRefresh = false, { rejectWithValue }) => {
    try {
      const response = await api.getUserOrders("buyer", forceRefresh);
      if (!response.ok) {
        return rejectWithValue(response.error || "Failed to fetch orders");
      }
      return response.data;
    } catch (error) {
      return rejectWithValue(
        error instanceof Error ? error.message : "Unknown error"
      );
    }
  }
);

export const fetchSellerOrders = createAsyncThunk<
  Order[],
  boolean | undefined,
  { rejectValue: string }
>(
  "orders/fetchSellerOrders",
  async (forceRefresh = false, { rejectWithValue }) => {
    try {
      const response = await api.getUserOrders("seller", forceRefresh);
      if (!response.ok) {
        return rejectWithValue(
          response.error || "Failed to fetch seller orders"
        );
      }
      return response.data;
    } catch (error) {
      return rejectWithValue(
        error instanceof Error ? error.message : "Unknown error"
      );
    }
  }
);

export const fetchOrderById = createAsyncThunk<
  Order,
  string,
  { rejectValue: string }
>("orders/fetchById", async (orderId, { rejectWithValue }) => {
  try {
    const response = await api.getOrderById(orderId);
    if (!response.ok) {
      return rejectWithValue(response.error || "Failed to fetch order");
    }
    return response.data;
  } catch (error) {
    return rejectWithValue(
      error instanceof Error ? error.message : "Unknown error"
    );
  }
});

export const updateOrderStatus = createAsyncThunk<
  Order,
  { orderId: string; status: string },
  { rejectValue: string }
>("orders/updateStatus", async ({ orderId, status }, { rejectWithValue }) => {
  try {
    const response = await api.updateOrderStatus(orderId, status);
    if (!response.ok) {
      return rejectWithValue(response.error || "Failed to update order status");
    }
    return response.data;
  } catch (error) {
    return rejectWithValue(
      error instanceof Error ? error.message : "Unknown error"
    );
  }
});

export const raiseOrderDispute = createAsyncThunk<
  Order,
  { orderId: string; reason: string },
  { rejectValue: string }
>("orders/raiseDispute", async ({ orderId, reason }, { rejectWithValue }) => {
  try {
    const response = await api.raiseDispute(orderId, reason);
    if (!response.ok) {
      return rejectWithValue(response.error || "Failed to raise dispute");
    }
    return response.data;
  } catch (error) {
    return rejectWithValue(
      error instanceof Error ? error.message : "Unknown error"
    );
  }
});

const orderSlice = createSlice({
  name: "orders",
  initialState,
  reducers: {
    clearOrderState: (state) => {
      state.currentOrder = null;
    },
  },
  extraReducers: (builder) => {
    builder
      // Create order
      .addCase(createOrder.pending, (state) => {
        state.loading = "pending";
        state.error = null;
      })
      .addCase(createOrder.fulfilled, (state, action: PayloadAction<Order>) => {
        state.loading = "succeeded";
        state.currentOrder = action.payload;
        state.orders.unshift(action.payload);
      })
      .addCase(createOrder.rejected, (state, action) => {
        state.loading = "failed";
        state.error = action.payload as string;
      })

      // Fetch user orders
      .addCase(fetchUserOrders.pending, (state) => {
        state.loading = "pending";
        state.error = null;
      })
      .addCase(
        fetchUserOrders.fulfilled,
        (state, action: PayloadAction<Order[]>) => {
          state.loading = "succeeded";
          state.orders = action.payload;
        }
      )
      .addCase(fetchUserOrders.rejected, (state, action) => {
        state.loading = "failed";
        state.error = action.payload as string;
      })

      // Fetch seller orders
      .addCase(fetchSellerOrders.pending, (state) => {
        state.loading = "pending";
        state.error = null;
      })
      .addCase(
        fetchSellerOrders.fulfilled,
        (state, action: PayloadAction<Order[]>) => {
          state.loading = "succeeded";
          state.sellerOrders = action.payload;
        }
      )
      .addCase(fetchSellerOrders.rejected, (state, action) => {
        state.loading = "failed";
        state.error = action.payload as string;
      })

      // Fetch order by id
      .addCase(fetchOrderById.pending, (state) => {
        state.loading = "pending";
        state.error = null;
      })
      .addCase(
        fetchOrderById.fulfilled,
        (state, action: PayloadAction<Order>) => {
          state.loading = "succeeded";
          state.currentOrder = action.payload;
        }
      )
      .addCase(fetchOrderById.rejected, (state, action) => {
        state.loading = "failed";
        state.error = action.payload as string;
      })

      // Update order status
      .addCase(updateOrderStatus.pending, (state) => {
        state.loading = "pending";
        state.error = null;
      })
      .addCase(
        updateOrderStatus.fulfilled,
        (state, action: PayloadAction<Order>) => {
          state.loading = "succeeded";
          state.currentOrder = action.payload;

          // Update order in orders array
          const index = state.orders.findIndex(
            (o) => o._id === action.payload._id
          );
          if (index !== -1) {
            state.orders[index] = action.payload;
          }

          // Update order in sellerOrders array
          const sellerIndex = state.sellerOrders.findIndex(
            (o) => o._id === action.payload._id
          );
          if (sellerIndex !== -1) {
            state.sellerOrders[sellerIndex] = action.payload;
          }
        }
      )
      .addCase(updateOrderStatus.rejected, (state, action) => {
        state.loading = "failed";
        state.error = action.payload as string;
      })

      // Raise dispute
      .addCase(raiseOrderDispute.pending, (state) => {
        state.loading = "pending";
        state.error = null;
      })
      .addCase(
        raiseOrderDispute.fulfilled,
        (state, action: PayloadAction<Order>) => {
          state.loading = "succeeded";
          state.currentOrder = action.payload;

          // Update order in orders array
          const index = state.orders.findIndex(
            (o) => o._id === action.payload._id
          );
          if (index !== -1) {
            state.orders[index] = action.payload;
          }

          // Update order in sellerOrders array
          const sellerIndex = state.sellerOrders.findIndex(
            (o) => o._id === action.payload._id
          );
          if (sellerIndex !== -1) {
            state.sellerOrders[sellerIndex] = action.payload;
          }
        }
      )
      .addCase(raiseOrderDispute.rejected, (state, action) => {
        state.loading = "failed";
        state.error = action.payload as string;
      });
  },
});

export const { clearOrderState } = orderSlice.actions;
export default orderSlice.reducer;
