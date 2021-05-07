<template>
  <div class="chooseTokenBlock">
    <div v-if="loading === true" class="centerBlock">
      <loader />
    </div>
    <template v-else>
      <i-button v-if="!success" :disabled="buttonDisabled" block class="_margin-top-1" size="lg" variant="secondary" @click="relayTransfer">
        <template>
          <i class="ri-send-plane-fill" />
        </template>
        <span>
          <span>Relay Transfer</span>
        </span>
      </i-button>

      <div v-if="success">Transfer Success</div>

      <div class="errorText _text-center _margin-top-1">
        {{ error }}
      </div>

      <!-- <i-input ref="tokenSymbolInput" v-model="search" :placeholder="`Filter balances in ${tokensType}`" maxlength="10">
        <i slot="prefix" class="ri-search-line"></i>
      </i-input>
      <div class="tokenListContainer">
        <div v-for="item in displayedList" :key="item.symbol" class="tokenItem" @click="chooseToken(item)">
          <div class="tokenSymbol">{{ item.symbol }}</div>
          <div class="rightSide">
            <div class="balance">{{ item.balance }}</div>
          </div>
        </div>
        <div v-if="search && displayedList.length === 0" class="centerBlock">
          <span>
            Your search <b>"{{ search }}"</b> did not match any tokens
          </span>
        </div>
        <div v-else-if="displayedList.length === 0" class="centerBlock">
          <span>No balances yet. Please make a deposit or request money from someone!</span>
        </div>
      </div>
      suppress JSCheckFunctionSignatures
      <i-button block class="_margin-top-1" link size="lg" variant="secondary" @click="$accessor.openModal('NoTokenFound')"> Can't find a token? </i-button>
      <no-token-found /> -->
    </template>
  </div>
</template>

<script lang="ts">
import NoTokenFound from "@/blocks/modals/NoTokenFound.vue";
import { ZkInBalance } from "@/plugins/types";
import { walletData } from "@/plugins/walletData";
import { BigNumber, utils } from "ethers";
// import ethers from "ethers";

import Vue, { PropOptions } from "vue";
import { SignedTransaction } from "zksync/build/types";

type TokensType = "L1" | "L2";

export default Vue.extend({
  components: {
    NoTokenFound,
  },
  props: {
    transactionInfo: {
      type: Object,
      default: false,
      required: true,
    },
    onlyAllowed: {
      type: Boolean,
      default: false,
      required: false,
    },
    tokensType: {
      type: String,
      default: "L2",
      required: false,
    } as PropOptions<TokensType>,
  },
  data() {
    return {
      search: "",
      loading: false,
      error: "",
      buttonDisabled: false,
      success: false,
    };
  },
  computed: {
    balances(): ZkInBalance[] {
      return this.tokensType === "L2" ? this.$accessor.wallet.getzkBalances : this.$accessor.wallet.getInitialBalances;
    },
  },
  mounted() {
    this.getTokenList();
    console.log("transactionInfo: ", this.transactionInfo);
  },
  destroyed() {
    this.error = "";
  },
  methods: {
    async relayTransfer() {
      this.loading = true;
      try {
        const tx = await this.signTransaction();
        await this.submitOrder(tx);
      } catch (e) {
        this.error = e.message;
      }

      console.log("waiting for relayer to submit transaction...");
      const syncWallet = walletData.get().syncWallet;

      const interval = setInterval(async () => {
        const { data } = await this.$axios.get(`http://localhost:4000/order/${syncWallet?.address()}`);
        if (!data) {
          console.log("order settled");
          clearInterval(interval);
          this.loading = false;
          this.success = true;
        }
        console.log("order: ", data);
      }, 2000);
    },
    async signTransaction(): Promise<SignedTransaction> {
      const syncWallet = walletData.get().syncWallet;
      let tx;

      const nonce = await syncWallet?.getNonce();

      const transfer = {
        to: this.transactionInfo.to,
        token: "ETH",
        amount: this.transactionInfo.amount,
        fee: BigNumber.from("0"),
        nonce: nonce ? nonce : 0,
      };

      console.log("transfer: ", transfer);

      tx = await syncWallet?.signSyncTransfer(transfer);

      if (!tx) {
        throw new Error("tx undefined");
      }

      return tx;
    },
    async submitOrder(signedTransaction: any) {
      const syncWallet = walletData.get().syncWallet;

      await this.$axios.post("http://localhost:4000/order", {
        id: syncWallet?.address(),
        transaction: signedTransaction,
      });
    },
    async getTokenList(): Promise<void> {
      this.loading = true;
      if (this.tokensType === "L2") {
        await this.$accessor.wallet.requestZkBalances({ accountState: undefined, force: false });
      } else {
        await this.$accessor.wallet.requestInitialBalances(false);
      }
      this.loading = false;
    },
  },
});
</script>
