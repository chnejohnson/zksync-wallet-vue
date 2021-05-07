<template>
  <!-- <transaction :from-route="fromRoute" type="transfer" /> -->
  <div class="transactionsPage">
    <div class="tileBlock transactionsTile">
      <div class="tileHeadline h3">Relayer</div>
      <div class="transactionsListContainer">
        <div v-if="loading === true" class="nothingFound">
          <loader class="_display-block" />
        </div>
        <div class="nothingFound">
          <div v-if="!isFinding && !orderIsFound" class="addressInput">
            <div class="walletContainer inputWallet" :class="{ error: error }">
              <div class="userImgPlaceholder userImg"></div>
              <!--suppress HtmlFormInputWithoutLabel -->
              <input ref="input" v-model="orderID" autocomplete="none" class="walletAddress" maxlength="45" placeholder="0x address" spellcheck="false" type="text" />
            </div>
          </div>

          <div v-if="isFinding && !orderIsFound">finding the order with ID: {{ orderID }}</div>

          <div v-if="orderIsFound">
            <p>Order Found</p>
            <i-button @click="submitTxs" block link size="lg" variant="secondary">Submit Transactions</i-button>
            <p v-if="success">Success!</p>
          </div>
        </div>
        <i-button @click="findOrder" block link size="lg" variant="secondary">{{ isFinding ? "Cancel" : "Find Order" }}</i-button>
      </div>
    </div>
  </div>
</template>

<script lang="ts">
import Transaction from "@/blocks/Transaction.vue";
import Context from "@nuxt/types";
import Vue from "vue";
import { Route } from "vue-router/types";
import { walletData } from "@/plugins/walletData";
import { wallet } from "zksync";
const { submitSignedTransactionsBatch } = wallet;

export default Vue.extend({
  components: {
    Transaction,
  },
  asyncData({ from }: Context.Context): { fromRoute: Route } {
    return {
      fromRoute: from,
    };
  },
  data() {
    return {
      loading: false,
      orderID: "",
      error: "",
      orderIsFound: false,
      signedTransaction: null,
      isFinding: false,
      success: false,
    };
  },
  methods: {
    findOrder() {
      console.log("press findOrder");
      if (!this.orderID) {
        this.error = "no orderID";
        return;
      }
      if (this.isFinding) {
        this.isFinding = false;
        return;
      }
      this.isFinding = true;
      const interval = setInterval(async () => {
        console.log("get order id: ", this.orderID);
        const res = await this.$axios.get(`http://localhost:4000/order/${this.orderID}`);
        console.log(res);
        if (res.data) {
          console.log(res.data);
          this.signedTransaction = res.data.transaction;
          this.orderIsFound = true;
          this.isFinding = false;
          clearInterval(interval);
          return;
        }

        this.$nextTick(() => {
          if (!this.isFinding) {
            clearInterval(interval);
          }
        });
      }, 2000);
    },
    async submitTxs() {
      const syncWallet = walletData.get().syncWallet;
      const syncProvider = walletData.get().syncProvider;
      const nonce = await syncWallet?.getNonce();

      const transfer = {
        to: syncWallet?.address(),
        token: "ETH",
        amount: "0",
        // @ts-ignore
        fee: await syncProvider?.getTransactionsBatchFee(["Transfer", "Transfer"], [syncWallet?.address(), syncWallet?.address()], "ETH"),
        nonce: nonce,
      };

      console.log("transfer: ", transfer);

      const tx = this.signedTransaction;
      // @ts-ignore
      const tx2 = await syncWallet?.signSyncTransfer(transfer);
      // @ts-ignore
      const batchTxs = await submitSignedTransactionsBatch(syncProvider, [tx, tx2]);
      await batchTxs[0].awaitReceipt();
      await batchTxs[1].awaitReceipt();

      console.log("settling...");
      try {
        await this.$axios.post("http://localhost:4000/settle", {
          id: this.orderID,
        });
      } catch (e) {
        throw new Error(e);
      }
      console.log("success");
      this.success = true;
    },
  },
});
</script>
